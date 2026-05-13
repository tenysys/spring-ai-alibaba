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

### 6.6 是否支持直接切换到历史发布版本

从当前实现看，`BasicAgent` **不支持直接把当前发布版本切换到某个历史版本号**。

现有能力主要包括：

- 发布当前应用
- 查询全部版本
- 查询 `latest`
- 查询 `lastPublished`
- 按版本号查询指定版本

但没有独立的“切换发布版本 / 回滚到指定历史版本”接口或服务方法。

当前发布动作的语义是：

```text
publishApp(appId)
  -> 读取 latestVersion
  -> 校验 latestVersion.config
  -> 将 latestVersion 置为 PUBLISHED
  -> 刷新 AppEntity.publishedVersion
```

因此：

- 当前生效的发布版本同一时刻只有一个
- 但版本表中可以保留多个历史 `PUBLISHED` 记录
- 对外正式执行始终以当前 `publishedVersion` 为准

### 6.7 如果要“回到旧版本”，当前实现的做法

虽然不能直接把发布指针切回历史版本，但可以通过“**用旧版本配置重新生成一个新版本并再次发布**”来达到近似回滚的效果。

可概括为：

```text
历史版本 config
  -> 写回当前应用
  -> 形成新的 latest draft
  -> publishApp(appId)
  -> 成为新的 publishedVersion
```

因此当前实现更准确地说是：

- 支持“基于旧版本内容重新发布”
- 不支持“直接切换 publishedVersion 到旧 versionId”

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

进一步看，`agent组件` 并不是独立于应用执行链之外的新型 Agent，而是**一个指向已发布应用的组件化包装**。

其核心关联字段是：

- `AppComponent.appId`
- `AppComponent.type`
- `AppComponent.config`

其中：

- `appId` 指向源应用
- `type` 用于区分 `Agent` / `Workflow`
- `config` 保存组件自己的输入输出映射配置，而不是完整的 `AgentConfig`

可以理解为：

```text
agent组件
  = 一个引用某个应用 appId 的组件记录
  + 一层组件入参/出参配置
```

#### 8.3.1 Agent组件与 BasicAgent 的关系

对 `BasicAgent` 来说，`agent组件` 与它的关系不是“拷贝出一个新的独立 Agent 实例”，而是：

1. 先由应用发布为组件，生成一条 `AppComponent` 记录
2. 组件记录中保存源应用 `appId`
3. 被其他 `BasicAgent` 引用时，通过 `AgentConfig.agentComponents` 挂载组件 code
4. 执行时再根据组件 code 找到组件记录，并回到源应用执行

因此其关系可表示为：

```text
BasicAgent A
  -> publish as agent component
  -> AppComponent(code, appId=A)

BasicAgent B
  -> AgentConfig.agentComponents = [componentCode]
  -> AppComponentToolCallback
  -> executeAgentComponent(...)
  -> AgentService.call(appId=A)
```

#### 8.3.2 Agent组件执行时使用哪个版本

当前实现下，`agent组件` 执行时并不绑定某个独立组件版本号，也不直接绑定某个应用历史版本号。

它的执行路径是：

```text
component code
  -> AppComponent
  -> appId
  -> AgentRequest.appId = appId
  -> AgentService.call(...)
  -> 读取应用 pubConfigStr
```

因此：

- `agent组件` 最终执行的是源应用当前的**发布版本**
- 不是草稿版本
- 也不是某个固定历史版本号

如果源 `BasicAgent` 后续重新发布，组件调用实际会跟着新的当前发布版本走。

#### 8.3.3 Agent组件自身是否有独立版本控制

从当前实现看，`agent组件` **没有像 `BasicAgent` 一样的独立版本表与版本控制体系**。

组件侧当前只有：

- 组件状态：`published`
- 组件状态：`deleted`
- 单条组件记录上的 `config`
- `needUpdate` 标记

也就是说：

```text
BasicAgent
  -> AppEntity + AppVersionEntity
  -> 有 draft / published / published_editing

agent组件
  -> AppComponentEntity
  -> 无独立 version 表
  -> 无 latestVersion / publishedVersion
```

所以组件更新更接近“直接修改组件配置记录”，而不是“生成新组件版本”。

### 8.4 Workflow组件

- 配置来源：`AgentConfig.workflowComponents`
- 运行时形式：组件工具回调

`workflow组件` 与 `agent组件` 的组件化机制基本一致，只是最终落点不是 `AgentService`，而是 `WorkflowService`。

其关系可表示为：

```text
Workflow 应用
  -> publish as workflow component
  -> AppComponent(code, appId=workflowAppId)

BasicAgent
  -> AgentConfig.workflowComponents = [componentCode]
  -> AppComponentToolCallback(type=Workflow)
  -> executeWorkflowComponent(...)
  -> WorkflowService.call(appId=workflowAppId)
```

#### 8.4.1 Workflow组件与 BasicAgent 的关系

当 `BasicAgent` 挂载 `workflowComponents` 时，本质上是把某个已发布工作流应用暴露为一个可被模型 tool call 调用的外部能力。

因此：

- `BasicAgent` 负责发起工具调用
- `workflow组件` 负责把调用转发到工作流应用
- 实际执行仍然发生在源工作流应用自身

#### 8.4.2 Workflow组件执行时使用哪个版本

与 `agent组件` 一样，`workflow组件` 执行时也走源应用的当前发布配置，而不是草稿配置或某个组件自身版本。

因此它同样具备以下特点：

- 组件只是引用层
- 真正的运行配置仍由源应用发布版本决定
- 组件本身没有独立版本表

#### 8.4.3 组件详情中的配置合并

无论 `agent组件` 还是 `workflow组件`，组件详情查询时都会将：

1. 源应用当前发布配置推导出的输入结构
2. 组件表中保存的组件配置

进行合并后返回。

这意味着组件配置更偏向于：

- 参数别名
- 参数默认值
- 参数显示与必填控制
- 输入输出 schema 适配

而不是保存一份完整可独立运行的应用执行配置。

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

其中，`model` 的装配需要和 `modelProvider` 配合来看。

在当前实现中，这两个字段职责不同：

- `modelProvider`：决定使用哪一个模型服务提供方配置
- `model`：决定在该提供方下实际调用哪个模型名

可以理解为：

```text
modelProvider = 调哪个模型平台 / 账号 / endpoint
model = 在该平台上具体调用哪个模型
```

因此 `BasicAgent` 的模型装配并不是只靠 `model` 一个字段完成，而是拆成两段：

```text
AgentConfig.modelProvider
  -> ModelFactory.getChatModel(...)
  -> 构建 ChatModel

AgentConfig.model
  -> OpenAiChatOptions.model(...)
  -> 写入本次模型调用参数
```

进一步说：

- `buildChatOptions(...)` 负责把 `config.getModel()` 写入 `chatOptions`
- `buildChatModel(...)` 负责把 `config.getModelProvider()` 转换为真正可用的 `ChatModel`

两者最后会在执行时汇合：

```text
ChatModel
  + chatOptions(model=xxx)
  + Prompt(messages, chatOptions)
  -> ChatClient 调用模型
```

##### 10.3.1.1 为什么需要 modelProvider

仅有 `model` 还不足以完成模型调用，因为 `model` 只表示模型名，不能表达：

- 使用哪套 `apiKey`
- 请求发往哪个 `endpoint`
- 使用哪个 provider 的网关或账号

因此需要 `modelProvider` 作为 provider 配置定位键，用来查找：

- credential
- endpoint
- provider 级别配置

当前实现中，`ModelFactory` 会根据 `modelProvider` 获取 provider 对应的 credential，并构造 `OpenAiApi`，再进一步构造 `ChatModel`。

这意味着同一个 `model` 名称在不同 provider 下可以有不同的实际调用目标。

##### 10.3.1.2 当前实现特点

从当前实现看，`modelProvider` 主要负责提供连接信息，而 `model` 主要负责指定模型名称。

也就是说：

- `modelProvider` 决定“连到哪里”
- `model` 决定“调用什么”

当前 `ModelFactory` 统一通过 OpenAI Compatible 的方式构造 `OpenAiChatModel`，因此不同 provider 的差异主要体现在：

- `apiKey`
- `baseUrl / endpoint`
- 相关 provider 配置

而不是 `BasicAgentExecutor` 中存在多套完全不同的模型调用主流程。

#### 10.3.2 buildToolCallbackProvider

该步骤会根据 `AgentConfig` 中的能力配置，组装统一的工具回调提供器：

- `tools` -> `PluginToolCallback`
- `mcpServers` -> `McpToolCallback`
- `agentComponents` -> `AppComponentToolCallback(type=Agent)`
- `workflowComponents` -> `AppComponentToolCallback(type=Workflow)`

运行时这些能力会以 `ToolCallback[]` 的形式注入模型调用参数中。

进一步看，`buildToolCallbackProvider(...)` 本身并不直接执行工具，而是创建一个统一的 `CompositeToolCallbackProvider`，负责把不同来源的外部能力转换为模型可见的 `ToolCallback` 列表。

可概括为：

```text
AgentConfig
  -> CompositeToolCallbackProvider
  -> ToolCallback[]
  -> chatOptions.setToolCallbacks(...)
```

##### 10.3.2.1 插件装配链

插件能力来源于 `AgentConfig.tools`。

装配过程如下：

1. 从 `AgentConfig.tools` 取出 `toolId`
2. 通过 `pluginService.getTools(toolIds)` 读取插件工具定义
3. 为每个插件工具构建 `PluginToolCallback`
4. 在 `PluginToolCallback.getToolDefinition()` 中，将插件/OpenAPI 配置转换为 `ToolDefinition`

可表示为：

```text
AgentConfig.tools
  -> pluginService.getTools(...)
  -> PluginToolCallback
  -> ToolDefinition(name, description, inputSchema)
```

插件的 schema 不是平台内部手写固定的，而是由插件本身的 OpenAPI / Tool 配置推导出来。

##### 10.3.2.2 MCP装配链

MCP 能力来源于 `AgentConfig.mcpServers`。

装配过程如下：

1. 从 `AgentConfig.mcpServers` 取出 `serverCode`
2. 通过 `mcpServerService.listByCodes(... needTools=true)` 查询 MCP server 及其暴露的 tools
3. 为每个 MCP tool 构建 `McpToolCallback`
4. 在 `McpToolCallback.getToolDefinition()` 中，直接使用 MCP tool 自身返回的 `name / description / inputSchema`

可表示为：

```text
AgentConfig.mcpServers
  -> mcpServerService.listByCodes(... needTools=true)
  -> McpServerDetail + McpTool
  -> McpToolCallback
  -> ToolDefinition(name, description, inputSchema)
```

因此 MCP 的 tool schema 来源不是平台本地生成，而是 MCP server 暴露出来的工具描述。

##### 10.3.2.3 组件装配链

组件能力来源于：

- `AgentConfig.agentComponents`
- `AgentConfig.workflowComponents`

装配过程如下：

1. 从配置中取出组件 code 列表
2. 通过 `appComponentManager.getToolCallSchema(codes)` 查询组件 schema
3. 为每个组件构建 `AppComponentToolCallback`
4. 按组件类型区分 `Agent` / `Workflow`

可表示为：

```text
AgentConfig.agentComponents / workflowComponents
  -> appComponentManager.getToolCallSchema(...)
  -> AppComponentToolCallback(type=Agent/Workflow)
  -> ToolDefinition(name, description, inputSchema)
```

组件的 schema 来源于组件配置 `AppComponentConfig` 与源应用输入结构的组合结果，而不是插件定义或 MCP server 原始返回值。

##### 10.3.2.4 extraParams 的装配

无论是插件、MCP 还是组件，`buildToolCallbackProvider(...)` 都会同时接收 `request.extraParams`。

这些参数不会直接成为 prompt 的一部分，而是在工具真正执行前，通过 `ToolArgumentsHelper.mergeToolArguments(...)` 与模型生成的 `functionInput` 合并。

其作用可以理解为：

- 模型负责生成主参数
- 平台负责补充额外业务参数
- 若模型已提供同名参数，则优先保留模型生成值

##### 10.3.2.5 三类工具装配的共同点与差异

三者共同点是：

- 最终都会被包装成 `ToolCallback`
- 最终都会以 `ToolCallback[]` 写入 `chatOptions`
- 最终都会进入统一的 tool calling 体系

但三者的差异主要在三个维度：

```text
插件
  -> 来源：平台插件配置
  -> schema 来源：OpenAPI / Tool 配置
  -> 本质：外部 HTTP/OpenAPI 能力接入

MCP
  -> 来源：MCP server 配置
  -> schema 来源：MCP server 暴露的 tool schema
  -> 本质：外部 MCP 能力接入

组件
  -> 来源：平台内部已发布应用组件
  -> schema 来源：AppComponentConfig + 应用输入结构
  -> 本质：内部应用能力复用
```

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

进一步看，`buildMessages(...)` 构建的是**真正发送给模型的对话消息列表**，其结果会参与：

```text
List<Message>
  -> Prompt(messages, chatOptions)
  -> ChatClient.prompt(prompt)
```

也就是说，这里的“消息”主要表示 prompt 上下文，而不是 `BasicAgent` 的全部运行时能力配置。

##### 10.3.3.1 消息来源

消息来源有两部分：

1. `AgentConfig.instructions`
2. `AgentRequest.messages`

其中：

- `instructions` 表示应用级系统提示词
- `request.messages` 表示本次调用传入的会话内容

如果 `config.instructions` 不为空，且 `request.messages` 的第一条消息不是 `SYSTEM`，则执行器会先补一条系统消息，再继续处理请求中的消息列表。

可概括为：

```text
config.instructions
  -> 可补充为首条 SYSTEM message

request.messages
  -> 逐条转换为模型消息
```

##### 10.3.3.2 角色转换规则

`buildMessages(...)` 会遍历 `AgentRequest.messages`，按角色与内容类型转换：

- `SYSTEM` -> `buildInstructions(...)`
- `USER + TEXT` -> `UserMessage`
- `USER + MULTIMODAL` -> `buildMultimodelMessage(...)`
- `ASSISTANT` -> `AssistantMessage`

因此，业务层的 `ChatMessage` 会被转换为 Spring AI 的标准消息类型：

- `SystemMessage`
- `UserMessage`
- `AssistantMessage`

这些消息共同组成一次模型调用前的 `Prompt`。

##### 10.3.3.3 SYSTEM消息构建

`SYSTEM` 消息并不是简单的字符串包装，执行器会在 `buildInstructions(...)` 中继续处理：

- 文件检索相关提示词
- citation 提示词
- prompt variables 模板变量

处理逻辑可以概括为：

```text
instructions
  -> 合并 file search prompt / citation prompt
  -> 读取 AgentConfig.promptVariables 默认值
  -> 读取 request.promptVariables 覆盖默认值
  -> 移除空变量
  -> 生成最终 SYSTEM message
```

其中 prompt variables 的来源分两层：

- `AgentConfig.promptVariables`：配置中的默认值
- `AgentRequest.promptVariables`：本次请求的覆盖值

若未开启知识库检索，则 `instructions` 会直接通过模板引擎渲染为最终 `SystemMessage`。

##### 10.3.3.4 与知识库检索的关系

知识库相关配置虽然会影响系统提示词，但**知识库本身并不是在 `buildMessages(...)` 中直接拼成普通消息**。

更准确地说：

- `buildMessages(...)` 只负责构建基础消息列表
- `buildInstructions(...)` 负责保留或准备 system prompt 模板
- 真正的文档检索和 `{documents}` 占位符填充发生在 `KnowledgeBaseRetrievalAdvisor`

因此知识库链路是：

```text
AgentConfig.fileSearch
  -> buildChatClient(...)
  -> KnowledgeBaseRetrievalAdvisor
  -> 检索文档
  -> 用检索结果改写 system prompt
  -> 再参与模型调用
```

这意味着：

- 知识库配置不直接表现为 `messages`
- 检索结果也不是初始 `request.messages` 的一部分
- 它属于调用前的 prompt 增强过程

##### 10.3.3.5 多模态消息构建

当 `USER` 消息的 `contentType = MULTIMODAL` 时，执行器会调用 `buildMultimodelMessage(...)`。

该方法要求 `content` 为 `List<MultimodalContent>`，典型支持：

- 文本片段
- 图片 URL
- 本地文件路径
- Base64 数据

最终会被组装成一条带 `text + media` 的 `UserMessage`。

因此，多模态消息在模型看来仍然是一条用户消息，只是该消息同时附带媒体资源。

##### 10.3.3.6 与工具 / MCP 的边界

`buildMessages(...)` 构建的是“模型看到的对话内容”，而工具、MCP、组件等能力并不通过消息列表注入。

这些能力的进入方式分别是：

- `tools` -> `PluginToolCallback`
- `mcpServers` -> `McpToolCallback`
- `agentComponents` -> `AppComponentToolCallback`
- `workflowComponents` -> `AppComponentToolCallback`

随后统一以 `ToolCallback[]` 的形式写入 `chatOptions`。

因此三者职责可以明确区分为：

```text
messages
  -> 负责“说什么”

tool callbacks
  -> 负责“能调用什么工具”

retrieval advisor
  -> 负责“调用前补充什么文档上下文”
```

##### 10.3.3.7 当前实现的一个注意点

业务层 `MessageRole` 中包含 `TOOL`，但当前 `buildMessages(...)` 主要只处理：

- `SYSTEM`
- `USER`
- `ASSISTANT`

因此从现有实现看，请求侧的消息构建主路径并不依赖外部直接传入 `TOOL` 消息；工具调用结果更多是在模型调用后的 tool calling 流程中补入会话历史，而不是在初始 `buildMessages(...)` 阶段构造。

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

##### 10.3.4.1 知识库装配入口

`BasicAgent` 的知识库能力来自 `AgentConfig.fileSearch`。

该配置主要描述：

- `kbIds`
- `enableSearch`
- `enableCitation`
- `topK`
- `retrieveMaxLength`
- `similarityThreshold`
- `hybridWeight`
- `searchType`
- `enableRerank`
- `rerankProvider`
- `rerankModel`

其中最关键的装配开关是：

- `enableSearch = true`
- `kbIds` 非空

只有同时满足这两个条件，`buildChatClient(...)` 才会真正为本次调用挂载知识库检索能力。

可概括为：

```text
AgentConfig.fileSearch
  -> enableSearch?
  -> kbIds 非空?
  -> DocumentRetrieverManager.getDocumentRetriever(...)
  -> KnowledgeBaseRetrievalAdvisor
  -> ChatClient.defaultAdvisors(...)
```

##### 10.3.4.2 检索器与 Advisor 装配

当知识库检索开启时，执行器并不会直接把知识库内容塞进 `messages`，而是先做两步装配：

1. 根据 `fileSearch` 配置，通过 `DocumentRetrieverManager` 构建 `DocumentRetriever`
2. 再用该 `DocumentRetriever`、`AgentContext`、`CommonConfig` 组装 `KnowledgeBaseRetrievalAdvisor`

随后将该 advisor 挂到 `ChatClient` 上。

因此知识库能力的运行时落点不是 `buildMessages(...)`，而是：

```text
buildChatClient(...)
  -> retrievalAdvisor
  -> ChatClient
  -> 调用模型前动态增强 prompt
```

##### 10.3.4.3 知识库如何参与一次模型调用

知识库真正生效是在模型调用前的 advisor 阶段，而不是在初始消息构建阶段。

`KnowledgeBaseRetrievalAdvisor` 的核心流程可以概括为：

1. 从当前 `Prompt` 中取出用户问题与指令上下文
2. 构造检索 `Query`
3. 调用 `documentRetriever.retrieve(query)` 获取文档
4. 将文档文本拼接为 `documentContext`
5. 以 `{documents}` 为占位符参数，与 prompt variables 一起注入 system prompt 模板
6. 用新的 `SystemMessage` 替换原有 system message
7. 再将增强后的 prompt 交给模型

可表示为：

```text
Prompt
  -> Query(text=user message, history=instructions)
  -> retrieve documents
  -> documents -> {documents}
  -> 重建 SystemMessage
  -> 增强后的 Prompt
  -> ChatModel
```

因此，知识库内容进入模型的方式不是“追加一条普通聊天消息”，而是“改写系统提示词并补充检索上下文”。

##### 10.3.4.4 与 buildMessages 的边界

知识库链路与消息构建链路职责不同：

- `buildMessages(...)`：负责基础对话消息
- `buildInstructions(...)`：负责准备可被模板渲染的 system prompt
- `KnowledgeBaseRetrievalAdvisor`：负责在调用前把检索结果注入 prompt

也就是说：

```text
messages
  -> 表达原始会话上下文

fileSearch
  -> 决定是否挂载知识库检索能力

retrieval advisor
  -> 决定如何把检索结果注入 prompt
```

##### 10.3.4.5 与 promptVariables / citation 的关系

知识库装配和 prompt variables、citation 之间是串联关系：

- 在 `buildInstructions(...)` 阶段，会先根据 `enableCitation`、默认 prompt、prompt variables 准备 system prompt 模板
- 在 `KnowledgeBaseRetrievalAdvisor` 阶段，会继续把 `{documents}` 和 `context.promptVariables` 一起填充到模板中

因此：

- citation 影响 system prompt 的提示策略
- prompt variables 影响模板变量替换
- documents 影响最终注入给模型的检索上下文

三者最终共同汇入增强后的 `SystemMessage`。

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

#### 10.6.1 插件、MCP、组件执行差异

虽然三者最终都通过 `ToolCallingManager + ToolCallback` 被统一调度，但它们的真正执行落点并不相同。

##### 10.6.1.1 插件执行

插件执行链可以概括为：

```text
模型 tool call
  -> PluginToolCallback.call(...)
  -> mergeToolArguments(...)
  -> ToolExecutionService.callOpenApi(...)
  -> HTTP/OpenAPI 调用外部服务
```

因此插件更偏向于“**外部 API 封装**”。

##### 10.6.1.2 MCP执行

MCP 执行链可以概括为：

```text
模型 tool call
  -> McpToolCallback.call(...)
  -> mergeToolArguments(...)
  -> McpServerService.callTool(...)
  -> MCPManager.callTool(...)
  -> MCP server
```

因此 MCP 更偏向于“**外部 MCP 协议工具接入**”。

##### 10.6.1.3 组件执行

组件执行链可以概括为：

```text
模型 tool call
  -> AppComponentToolCallback.call(...)
  -> AppComponentManager.executeAgentComponent(...)
     或 executeWorkflowComponent(...)
  -> AgentService / WorkflowService
  -> 源应用执行链
```

因此组件更偏向于“**平台内部应用能力转发与复用**”。

##### 10.6.1.4 为什么说组件和插件 / MCP 不同

插件和 MCP 都是在把“外部能力”接入 `BasicAgent`：

- 插件：对接外部 HTTP / OpenAPI
- MCP：对接外部 MCP server

而组件则是在把“平台内部已发布应用”重新暴露为模型可调用的工具能力：

- agent 组件：复用内部 `BasicAgent`
- workflow 组件：复用内部 workflow 应用

所以三者虽然在模型侧都表现为 tool call，但从架构职责上看：

```text
插件 / MCP
  -> 外部能力接入

组件
  -> 内部应用能力复用
```

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
