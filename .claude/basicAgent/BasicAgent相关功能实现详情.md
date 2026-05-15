# BasicAgent相关功能实现详情

## 1. 说明

本文档用于补充说明 `BasicAgent` 依赖的几类核心能力本身是如何实现的，包括：

- MCP
- 插件
- 组件
- 知识库
- 模板及模板变量
- 记忆

与 [BasicAgent实现详情.md](I:\java\workplace\spring-ai-alibaba\.claude\sophicAgent\BasicAgent实现详情.md) 的区别是：

- `BasicAgent实现详情.md` 重点说明这些能力与 `BasicAgent` 的关联方式
- 本文档重点说明这些能力**自身的实现链路、核心类、运行时行为与当前实现特点**

## 2. 总体视图

从当前实现看，这几类能力大致分成两组：

```text
工具类能力
  -> 插件
  -> MCP
  -> 组件
  -> 最终统一进入 ToolCallback 体系

Prompt增强类能力
  -> 知识库
  -> 模板与模板变量
  -> 记忆
  -> 最终在消息构建或 Advisor 层生效
```

其中：

- 插件、MCP、组件属于“模型可调用外部能力”
- 知识库、模板变量、记忆属于“模型调用前的上下文增强能力”

### 2.1 模型实现

#### 2.1.1 核心职责

模型能力的本质是：

```text
根据应用配置中的 modelProvider + model
  -> 找到 provider 凭证与 endpoint
  -> 构建底层 ChatModel
  -> 再叠加本次调用的 chatOptions
  -> 发起真正的模型请求
```

因此模型层解决的是：

- 连接到哪个模型服务
- 本次调用具体用哪个模型名
- 生成参数如何传入

#### 2.1.2 核心类

模型相关核心类主要包括：

- `BasicAgentExecutor`
- `ModelFactory`
- `ProviderManager`
- `ModelProvider`
- `ModelCredential`

#### 2.1.3 `modelProvider` 与 `model` 的分工

从当前实现看，这两个字段职责不同：

```text
modelProvider
  -> 决定“连到哪一个 provider 配置”
  -> 提供 apiKey / endpoint 等连接信息

model
  -> 决定“本次调用时使用哪个模型名”
```

也就是说：

- `modelProvider` 更偏向连接层与凭证层
- `model` 更偏向调用参数层

#### 2.1.4 `BasicAgentExecutor` 中的模型装配

`BasicAgentExecutor` 会把模型装配拆成两段：

1. `buildChatOptions(config)` 负责构造调用参数
2. `buildChatModel(config)` 负责构造真正的 `ChatModel`

可表示为：

```text
AgentConfig.model
  -> OpenAiChatOptions.model(...)

AgentConfig.parameter
  -> maxTokens / temperature / topP / repetitionPenalty

AgentConfig.modelProvider
  -> ModelFactory.getChatModel(...)
  -> ChatModel
```

两者最后会在：

```text
ChatClient.prompt(new Prompt(messages, chatOptions))
```

这一层汇合。

#### 2.1.5 `buildChatOptions(...)` 的职责

当前 `buildChatOptions(...)` 主要构造的是 `OpenAiChatOptions`，包括：

- `model`
- `maxTokens`
- `temperature`
- `topP`
- `presencePenalty`（由 `repetitionPenalty` 映射）
- `streamUsage(true)`
- `internalToolExecutionEnabled(false)`

因此它的职责是“本次调用参数装配”，而不是 provider 连接装配。

#### 2.1.6 `ModelFactory.getChatModel(...)` 的职责

`ModelFactory.getChatModel(provider)` 的主要流程是：

1. 根据 provider code 获取 `ModelCredential`
2. 基于 credential 构造 `OpenAiApi`
3. 基于 `OpenAiApi` 构造 `OpenAiChatModel`
4. 绑定观测能力 `ObservationRegistry`
5. 设置自定义 observation convention

可表示为：

```text
provider
  -> getModelCredential(provider, null)
  -> buildOpenAiApi(credential)
  -> OpenAiChatModel.builder().openAiApi(...)
  -> ChatModel
```

当前实现的一个重要特点是：

- 不同 provider 最终统一被适配为 `OpenAI Compatible` 调用方式

因此 `BasicAgent` 侧并没有按 provider 分出多套完全不同的 ChatModel 主流程。

#### 2.1.7 provider 凭证的来源

`ModelFactory` 自己不直接查数据库，而是通过 `ProviderManager.getProviderDetail(...)` 获取 provider 详情。

其关键链路是：

```text
provider code
  -> ProviderManager.getProviderDetail(...)
  -> ProviderConfigInfo
  -> ModelCredential
```

`ModelCredential` 当前主要包含：

- `endpoint`
- `apiKey`
- `completionsPath`
- `embeddingsPath`

其中真正用于 chat model 的核心字段是：

- `endpoint`
- `apiKey`

#### 2.1.8 凭证的存储与解密

从 `ProviderManager.toProviderConfig(...)` 看，provider 的 credential 在持久化层是 JSON 形式保存的，并且：

- `apiKey` 以加密形式存储
- 读取时会通过 `RSACryptUtils.decrypt(...)` 解密
- 在部分场景下可做脱敏展示

因此 provider 凭证链路大致是：

```text
ProviderEntity.credential
  -> JSON
  -> ModelCredential
  -> 解密 apiKey
  -> 返回给 ModelFactory 使用
```

#### 2.1.9 `buildOpenAiApi(...)` 的职责

`ModelFactory.buildOpenAiApi(...)` 主要负责：

1. 设置 `apiKey`
2. 设置统一错误处理器
3. 设置基础 headers
4. 处理 `endpoint`

其中 endpoint 处理有一个明确细节：

- 如果 endpoint 以 `/v1` 结尾，会先去掉 `/v1`
- 因为 Spring AI 客户端后续会自己补标准路径

因此 provider 配的 endpoint 更像“baseUrl”，而不是完整 chat completions 路径。

#### 2.1.10 `ModelProvider` 接口的作用

`ModelProvider` 更偏向 provider 元信息与校验层，而不是直接参与每次调用时的 ChatModel 创建。

它主要定义：

- provider code/name/description
- 预置模型列表
- protocol
- endpoint
- credential specs
- credential 校验逻辑
- 模型参数规则

因此 `ModelProvider` 在当前架构中的主要作用是：

```text
provider 元数据定义
  + credential 规范
  + 参数规则定义
```

而真正运行时构建模型实例的核心仍然集中在 `ModelFactory`。

#### 2.1.11 embedding 与 reranker 也是模型能力的一部分

虽然 `BasicAgent` 主执行链直接用的是 `ChatModel`，但从 `ModelFactory` 看，模型能力并不只包含 chat：

- `getEmbeddingModel(...)`
- `getDocumentRanker(...)`

这意味着在当前系统里：

- 对话模型
- 向量化模型
- rerank 模型

本质上都复用了同一套 provider/credential 管理思想。

#### 2.1.12 embedding 模型实现

`getEmbeddingModel(...)` 的主要流程是：

1. 根据 `IndexConfig.embeddingProvider + embeddingModel` 获取 credential
2. 基于同样的 `OpenAiApi` 构造 `OpenAiEmbeddingModel`
3. 根据模型名推导 embedding dimension
4. 构造 `OpenAiEmbeddingOptions`

因此 embedding 能力当前同样走 OpenAI Compatible 适配。

#### 2.1.13 reranker 模型实现

`getDocumentRanker(...)` 的主要流程是：

1. 根据 `searchOptions.rerankProvider + rerankModel` 获取 credential
2. 构造 `DashScopeApi`
3. 构造 `DashScopeRerankerOptions`
4. 构造 `DashscopeReranker`

因此 reranker 与 chat/embedding 不完全一样：

- chat/embedding 当前统一使用 OpenAI Compatible
- reranker 当前明显走 DashScope 专有实现

#### 2.1.14 当前实现特点

当前模型能力的主要特点是：

- `modelProvider` 决定 provider 凭证与 endpoint
- `model` 决定本次实际调用模型名
- chat model 当前统一适配为 `OpenAI Compatible`
- provider credential 通过 `ProviderManager` 获取并解密
- embedding 与 reranker 也复用同一套 provider/credential 管理思路

从架构上可以概括为：

```text
ProviderManager
  -> 提供 provider 配置与 credential

ModelFactory
  -> 把 credential 变成可调用模型实例

BasicAgentExecutor
  -> 把模型实例与本次调用参数组装进执行链
```

#### 2.1.15 provider 配置录入入口

模型 provider 的配置录入入口主要在 `ProviderController`。

新增 provider 时，请求模型大致是：

```text
AddProviderRequest
  -> name
  -> description
  -> icon
  -> credential_config
  -> protocol
  -> supported_model_types
```

其中 `credential_config` 是前端/调用方传入 provider 凭证的直接入口。

#### 2.1.16 provider 凭证录入与加密

从当前实现看，新增或更新 provider 时，controller 层会先把请求里的 `credential_config` 转成 `ModelCredential`。

对于 OpenAI 协议，主要处理：

- `endpoint`
- `api_key`

并且会在写入前对 `api_key` 做 RSA 加密。

可表示为：

```text
request.credential_config
  -> endpoint
  -> api_key
  -> RSACryptUtils.encrypt(api_key)
  -> ModelCredential
```

这意味着：

- 前端传入的是明文 `api_key`
- 持久化前会转为密文

#### 2.1.17 provider 持久化

`ProviderManager.addProvider(...)` / `updateProvider(...)` 会把 `ProviderConfigInfo` 转为 `ProviderEntity`。

其中 credential 的保存方式是：

```text
ProviderConfigInfo.credential
  -> JsonUtils.toJson(...)
  -> ProviderEntity.credential
```

也就是说 provider 凭证在数据库层是：

- 一段 JSON
- 其中敏感字段可能已经加密

除了数据库持久化之外，provider 配置还会被放入 Redis 缓存。

#### 2.1.18 provider 读取闭环

运行时读取 provider 的闭环可以概括为：

```text
ProviderController / ProviderManager 写入
  -> ProviderEntity.credential(JSON)
  -> ProviderManager.getProviderDetail(...)
  -> toProviderConfig(...)
  -> 反序列化为 ModelCredential
  -> 解密 apiKey
  -> ModelFactory.getChatModel(...)
```

因此模型配置从“前端录入”到“运行时实例化”的完整链路已经闭环。

#### 2.1.19 credential specs 的作用

从 `ProviderController.getProviderDetail(...)` 和 `ModelProvider` 接口可以看出，provider 还支持暴露：

- `credentialSpecs`

它们的作用更偏向：

- 告诉前端 provider 需要哪些凭证字段
- 哪些字段是敏感字段
- 如何校验 provider 凭证

因此 `ModelProvider` 在当前系统中还承担了一层“provider 配置元信息定义”的职责。

## 3. 插件实现

### 3.1 核心职责

插件能力的本质是：

```text
平台内定义一个 OpenAPI/HTTP 工具
  -> 暴露为 ToolDefinition
  -> 在模型发起 tool call 时
  -> 由平台执行一次真实 HTTP/OpenAPI 请求
```

因此插件更接近“**外部 API 封装层**”。

### 3.2 核心类

插件相关的核心类主要包括：

- `CompositeToolCallbackProvider`
- `PluginToolCallback`
- `ToolExecutionServiceImpl`
- `PluginService`
- `OpenApiUtils`

### 3.3 schema 生成

插件被装配为工具时，不是手写固定 schema，而是通过插件配置推导出模型可见的工具定义。

主链路是：

```text
AgentConfig.tools
  -> PluginService.getTools(toolIds)
  -> PluginToolCallback
  -> OpenApiUtils.buildToolCallSchema(tool)
  -> ToolDefinition(name, description, inputSchema)
```

也就是说：

- 工具名、描述、输入结构都来自插件定义
- 模型看到的是标准 `ToolDefinition`
- 平台内部则保留原始 OpenAPI/插件配置用于真正执行

### 3.4 执行链

插件执行链可以概括为：

```text
模型 tool call
  -> PluginToolCallback.call(functionInput)
  -> ToolArgumentsHelper.mergeToolArguments(...)
  -> ToolExecutionService.callOpenApi(...)
  -> HTTP 请求外部服务
  -> 返回结果字符串
```

其中 `PluginToolCallback` 的职责是：

- 把插件定义转换为 `ToolDefinition`
- 接收模型生成的参数 JSON
- 合并平台侧 `extraParams`
- 调用 `ToolExecutionService`

### 3.5 参数合并

插件执行前会先经过 `ToolArgumentsHelper.mergeToolArguments(...)`。

其行为是：

- 先把模型生成的 `functionInput` 解析成 `Map`
- 再查找 `extraParams[toolId]`
- 只对**模型未显式提供**的字段进行补充

可表示为：

```text
functionInput
  -> 模型主参数

extraParams[toolId]
  -> 平台补充参数

merge result
  -> 同名字段优先保留模型值
```

因此插件工具的参数来源有两层：

- 模型生成参数
- 平台补充参数

### 3.6 OpenAPI 调用执行

真正执行 HTTP/OpenAPI 请求的是 `ToolExecutionServiceImpl.callOpenApi(...)`。

它的主要职责包括：

1. 校验工具请求
2. 读取插件级配置与工具级配置
3. 组装请求地址、方法、header、query、path、body
4. 处理鉴权
5. 调用 `HttpClientManager`
6. 返回 `ToolExecutionResult`

### 3.7 插件鉴权实现

当前实现支持的鉴权方式主要包括：

- `Bearer`
- `Basic`
- `Custom`

并且 `Custom` 鉴权允许把鉴权信息放到：

- Header
- Query

因此插件层本身已经实现了“工具调用前的统一认证装配”。

### 3.8 参数位置映射

插件工具输入参数不是统一都放 body，而是按 `ApiParameter.location` 分发到：

- Header
- Query
- Path
- Body

也就是说，工具调用不是简单 JSON 透传，而是基于插件定义做了一次“HTTP 请求重建”。

### 3.9 当前实现特点

从当前实现看，插件能力的主要特点是：

- 面向 OpenAPI/HTTP 能力接入
- schema 来源于插件定义
- 参数支持 header/query/path/body 分发
- 支持鉴权注入
- 执行结果最终以字符串形式返回给模型侧工具调用链

## 4. MCP实现

### 4.1 核心职责

MCP 能力的本质是：

```text
平台注册一个 MCP Server
  -> 拉取该 Server 暴露的 tools
  -> 暴露给模型
  -> 模型发起 tool call 时
  -> 平台转发到 MCP Server 执行
```

因此 MCP 更接近“**外部 MCP 协议工具接入层**”。

### 4.2 核心类

MCP 相关核心类主要包括：

- `CompositeToolCallbackProvider`
- `McpToolCallback`
- `McpServerServiceImpl`
- `MCPManager`
- `McpServerService`

### 4.3 tool 列表发现

MCP tools 的发现链路是：

```text
AgentConfig.mcpServers
  -> McpServerService.listByCodes(... needTools=true)
  -> McpServerDetail
  -> McpTool 列表
  -> McpToolCallback
  -> ToolDefinition
```

这里的关键点是：

- 工具 schema 不是平台本地推导
- 而是直接来自 MCP Server 自己暴露的 `name / description / inputSchema`

### 4.4 tool schema 暴露

`McpToolCallback.getToolDefinition()` 会直接把 MCP tool 的：

- `name`
- `description`
- `inputSchema`

转换为模型可见的 `ToolDefinition`。

因此 MCP 工具在模型侧看到的定义，本质上就是 MCP server 的原始 tool 描述。

### 4.5 执行链

MCP 执行链可以概括为：

```text
模型 tool call
  -> McpToolCallback.call(functionInput)
  -> ToolArgumentsHelper.mergeToolArguments(...)
  -> McpServerService.callTool(...)
  -> MCPManager.callTool(...)
  -> McpSyncClient.callTool(...)
  -> MCP Server
```

### 4.6 `McpServerServiceImpl` 的职责

`McpServerServiceImpl.callTool(...)` 主要负责：

1. 校验 `serverCode / toolName / workspaceId`
2. 根据 `workspaceId + serverCode` 查找 MCP server 实体
3. 委托给 `MCPManager.callTool(...)`
4. 统一处理异常与错误结果

从职责上看，它更像 MCP 调用的“服务层入口”。

### 4.7 `MCPManager` 的职责

`MCPManager` 更靠近协议调用本身。

`callTool(...)` 的主要流程是：

1. 构造 `McpSyncClient`
2. `client.initialize()`
3. 构造 `McpSchema.CallToolRequest`
4. 执行 `client.callTool(...)`
5. 解析返回内容
6. 关闭 client

其中当前实现会把 MCP 返回的 content 中的 `text` 类型内容提取为平台自己的 `Content` 结构。

### 4.8 MCP tools 获取特点

从 `MCPManager.getTools(...)` 可以看出，当前 MCP tools 获取具备以下特点：

- 会尝试缓存工具列表
- 对远程拉取设置超时
- 获取失败时返回空列表而不是直接中断整个系统

因此工具发现层面有一定容错与缓存设计。

### 4.9 当前实现特点

当前 MCP 能力的特点是：

- schema 完全由 MCP server 决定
- 平台只做发现、转发与结果适配
- 执行依赖同步 MCP client
- 工具调用结果会被转成平台内部响应结构再返回给模型链路

## 5. 组件实现

### 5.1 核心职责

组件能力的本质不是“新工具类型”，而是：

```text
把平台内部已发布应用
  -> 包装成一个可被模型 tool call 调用的能力
```

因此组件更接近“**内部应用能力复用层**”。

### 5.2 核心类

组件相关核心类主要包括：

- `CompositeToolCallbackProvider`
- `AppComponentToolCallback`
- `AppComponentManager`
- `AppComponentConfig`

### 5.3 schema 生成

组件 schema 不是插件那样来自 OpenAPI，也不是 MCP 那样来自远端 server，而是由：

- 组件自身配置 `AppComponentConfig`
- 源应用输入结构

组合推导出来。

主链路是：

```text
component codes
  -> AppComponentManager.getToolCallSchema(codes)
  -> ToolCallSchema(name, description, inputSchema)
  -> AppComponentToolCallback
  -> ToolDefinition
```

### 5.4 `AppComponentManager.getToolCallSchema(...)`

这个方法的核心职责是：

1. 按 `code` 查找已发布组件
2. 读取组件配置
3. 提取输入参数定义
4. 构造标准 `ToolCallSchema`

因此组件在模型侧看到的输入结构，本质上是“组件包装后的输入协议”，而不是原始应用完整配置。

### 5.5 执行链

组件执行链可以概括为：

```text
模型 tool call
  -> AppComponentToolCallback.call(toolInput)
  -> ToolArgumentsHelper.mergeToolArguments(...)
  -> AppComponentRequest
  -> AppComponentManager.executeAgentComponent(...)
     或 executeWorkflowComponent(...)
  -> AgentService / WorkflowService
  -> 源应用执行链
```

### 5.6 `AppComponentToolCallback` 的职责

`AppComponentToolCallback` 主要负责：

- 把组件 schema 暴露为 `ToolDefinition`
- 接收模型工具输入
- 合并平台侧 `extraParams`
- 构造 `AppComponentRequest`
- 按组件类型分发到 agent 或 workflow 执行

它本身不负责组件内部参数映射的细节，那部分逻辑主要在 `AppComponentManager`。

### 5.7 组件入参适配

`AppComponentManager` 中最关键的是：

- `buildAgentRequest(...)`
- `buildWorkflowRequest(...)`

它们负责把 `AppComponentRequest.bizVars` 转换成真正下游可执行的：

- `AgentRequest`
- `WorkflowRequest`

### 5.8 Agent组件请求构建

`buildAgentRequest(...)` 的核心行为包括：

1. 通过组件 code 查找已发布组件
2. 读取组件输入配置
3. 将系统参数 `query` 映射成 `USER` 消息
4. 将用户自定义参数按组件配置映射成 `extraParams`
5. 生成最终 `AgentRequest`

因此 agent 组件并不是直接把所有 `bizVars` 拼成 prompt，而是：

```text
部分参数
  -> 转为 messages

部分参数
  -> 转为 extraParams
```

### 5.9 Workflow组件请求构建

`buildWorkflowRequest(...)` 的逻辑类似，但最终不是生成 `AgentRequest`，而是：

- 把系统参数和用户参数映射成 `TaskRunParam`
- 注入到 `WorkflowRequest.inputParams`

因此 workflow 组件的输入适配更偏向工作流参数协议，而不是对话协议。

### 5.10 当前实现特点

当前组件能力的特点是：

- 组件只是应用能力复用包装层
- schema 来源于组件输入配置
- 执行本质上仍回到原始 agent/workflow 应用链路
- 参数适配逻辑由 `AppComponentManager` 统一承担

## 6. 知识库实现

### 6.1 核心职责

知识库能力的本质是：

```text
在模型调用前
  -> 检索相关文档
  -> 把检索结果作为上下文注入 system prompt
```

因此知识库不是“工具调用”，而是“**Prompt 增强能力**”。

### 6.2 核心类

知识库相关核心类主要包括：

- `DocumentRetrieverManager`
- `KnowledgeBaseDocumentRetriever`
- `KnowledgeBaseRetrievalAdvisor`
- `VectorStoreFactory`
- `KnowledgeBaseService`

### 6.3 检索器装配

知识库装配入口是 `DocumentRetrieverManager.getDocumentRetriever(...)`。

它的职责是：

1. 根据 `kbIds` 查出知识库对象
2. 创建 `KnowledgeBaseDocumentRetriever`

可表示为：

```text
FileSearchOptions.kbIds
  -> KnowledgeBaseService.listKnowledgeBases(...)
  -> KnowledgeBaseDocumentRetriever
```

### 6.4 `KnowledgeBaseDocumentRetriever` 的职责

这个检索器负责真正跨多个知识库做检索。

其主要流程是：

1. 对每个知识库并行发起检索
2. 汇总所有返回文档
3. 按 score 倒序排序
4. 根据阈值过滤
5. 截断到 `topK`
6. 返回最终文档列表

因此它本质上是一个“**多知识库聚合检索器**”。

### 6.5 单知识库检索

对单个知识库的检索流程是：

```text
KnowledgeBase
  -> VectorStoreFactory.getVectorStore(...)
  -> 构造 SearchRequest
  -> vectorStore.similaritySearch(...)
  -> 可选 rerank
```

其中会用到的搜索参数包括：

- `searchType`
- `similarityThreshold`
- `topK`
- `hybridWeight`

同时还会构造过滤条件，限制：

- `workspaceId`
- `enabled = true`

### 6.6 rerank 实现

如果知识库配置开启了 `enableRerank`，则检索结果还会经过：

- `modelFactory.getDocumentRanker(searchOptions)`
- `DashscopeReranker.process(query, documents)`

因此当前实现支持“先召回，再重排”的知识库链路。

### 6.7 Advisor 注入

真正把知识库结果注入 prompt 的是 `KnowledgeBaseRetrievalAdvisor.before(...)`。

它的流程是：

1. 从当前 prompt 中取出 user message 与 instructions
2. 构造 `Query`
3. 调用 `documentRetriever.retrieve(query)`
4. 拼接文档文本为 `documentContext`
5. 构造 `promptParameters`
6. 将 `{documents}` 和普通 prompt variables 一起注入模板
7. 重建 `SystemMessage`
8. 用新的 system message 替换原有 system message

### 6.8 `{documents}` 占位符约束

当前实现有一个明确约束：

- 如果开启知识库检索
- 最终用于增强的 system prompt 模板中必须包含 `{documents}`

否则 `KnowledgeBaseRetrievalAdvisor` 会直接抛出参数错误。

因此在知识库场景下，提示词模板本身需要配合知识库能力使用。

### 6.9 当前实现特点

当前知识库能力的特点是：

- 不通过工具调用接入
- 通过 advisor 在调用前改写 prompt
- 支持多知识库并行检索
- 支持向量检索与 rerank
- 强依赖 system prompt 中的 `{documents}` 占位符

## 7. 模板与模板变量实现

### 7.1 核心职责

模板系统的本质是：

```text
把应用配置中的 instructions
  -> 视为可渲染模板
  -> 再用配置默认值与请求覆盖值
  -> 生成最终 SystemMessage
```

因此模板能力主要服务于 system prompt 的动态生成。

### 7.2 核心类

模板与模板变量相关核心类主要包括：

- `BasicAgentExecutor.buildInstructions(...)`
- `AgentConfig.PromptVariable`
- `AgentRequest.promptVariables`
- `SystemPromptTemplate`
- `KnowledgeBaseRetrievalAdvisor`

### 7.3 变量定义结构

`AgentConfig.promptVariables` 保存的不是单纯键值对，而是变量定义。

每个变量定义主要包含：

- `name`
- `type`
- `description`
- `defaultValue`

因此配置层更像：

```text
定义有哪些变量
  -> 每个变量叫什么
  -> 是什么类型
  -> 默认值是什么
```

### 7.4 变量最终值入口

运行时变量最终值有两个来源：

1. `AgentConfig.promptVariables[].defaultValue`
2. `AgentRequest.promptVariables`

其中：

- 配置层提供默认值
- 请求层提供本次调用覆盖值

### 7.5 普通场景下的渲染

未开启知识库时，`buildInstructions(...)` 会：

1. 从配置中取出 `promptVariables`
2. 组装 `name -> defaultValue`
3. 用 `AgentRequest.promptVariables` 覆盖同名项
4. 删除空值
5. 调用 `new SystemPromptTemplate(instructions).createMessage(map)`

可表示为：

```text
instructions
  + default prompt variables
  + request overrides
  -> final variable map
  -> SystemPromptTemplate.createMessage(...)
  -> SystemMessage
```

### 7.6 当前覆盖规则

当前实现并不是“请求里传什么变量都能用”，而是：

- 只有配置里已经声明过的变量
- 才能在请求时被覆盖

因此当前实现偏向：

```text
先声明变量
  -> 再允许请求覆盖
```

而不是任意动态注入新变量。

### 7.7 知识库场景下的延迟渲染

开启知识库后，模板渲染会延后一层。

此时 `buildInstructions(...)` 会：

- 先保留模板文本
- 先把普通 prompt variables 存到 `AgentContext.promptVariables`

后续到 `KnowledgeBaseRetrievalAdvisor` 阶段，再把：

- `{documents}`
- `context.promptVariables`

合并成 `promptParameters`，统一调用：

- `SystemPromptTemplate.createMessage(promptParameters)`

因此知识库场景下的最终 system prompt 生成分成两段：

```text
buildInstructions(...)
  -> 预装配普通变量

KnowledgeBaseRetrievalAdvisor
  -> 注入 documents
  -> 完成最终模板渲染
```

### 7.8 当前实现特点

当前模板与模板变量实现的特点是：

- 主要作用于 system prompt
- 运行时变量来源分“配置默认值”和“请求覆盖值”两层
- 请求只能覆盖已声明变量
- 开启知识库后会变成延迟渲染模式

## 8. 记忆实现

### 8.1 核心职责

记忆能力的本质是：

```text
为会话绑定一个 conversationId
  -> 把历史消息存入 ChatMemory
  -> 在后续请求中自动取回
```

因此记忆是“**跨请求会话上下文持久化能力**”。

### 8.2 核心类

记忆相关核心类主要包括：

- `AgentServiceImpl.memoryEnabled(...)`
- `BasicAgentExecutor.buildChatClient(...)`
- `MessageChatMemoryAdvisor`
- `ConversationChatMemory`
- `ChatMemory`

### 8.3 启用条件

当前实现中，记忆只有在同时满足以下条件时才会启用：

- 应用类型是 `AppType.BASIC`
- `config.getMemory() != null`
- `config.getMemory().getDialogRound() > 0`
- `request.getConversationId()` 非空

因此：

- 记忆不是默认总是开启
- 它依赖应用配置与请求会话标识共同决定

### 8.4 运行时装配

当记忆启用时，`BasicAgentExecutor.buildChatClient(...)` 会：

1. 构建 `MessageChatMemoryAdvisor`
2. 挂载到 `ChatClient`
3. 生成实际使用的 `conversationId`
4. 设置 advisor 参数 `CONVERSATION_ID`

可表示为：

```text
AgentConfig.memory
  -> memoryEnabled(...)
  -> MessageChatMemoryAdvisor(chatMemory)
  -> param(CONVERSATION_ID, appId + "_" + request.conversationId)
```

### 8.5 实际存储实现

当前 `ChatMemory` 的具体实现是 `ConversationChatMemory`。

它的核心特点是：

- 底层使用 Redis
- key 前缀是 `conversation_chat:%s`
- value 是消息队列 `Deque<Message>`
- 提供 `add / get / clear`

因此版本配置中保存的是“记忆配置”，真正的会话历史内容保存在 Redis。

### 8.6 写入逻辑

`ConversationChatMemory.add(...)` 的逻辑是：

1. 根据 `conversationId` 取 Redis 中已有历史
2. 如果没有则初始化一个 `Deque`
3. 追加新消息
4. 超过上限时尝试移除旧消息
5. 回写 Redis

最大缓存条数来自：

- `CommonConfig.maxConversationRoundInCache`

### 8.7 读取逻辑

`ConversationChatMemory.get(...)` 的逻辑较简单：

- 从 Redis 读取该 `conversationId` 对应的全部消息
- 若不存在则返回空列表

当前实现中有明显注释：

- `FIXME, return only topN messages`

这说明当前 `get(...)` 还没有真正做到按轮数精确裁剪读取结果。

### 8.8 `dialogRound` 的当前实际作用

虽然配置里有：

- `memory.dialogRound`

但从当前实现看，它主要起到：

- 作为是否启用记忆的判断条件之一

而并没有完整落实成“每次只精确取回多少轮消息”的硬限制参数。

因此当前实现更接近：

```text
dialogRound
  -> 记忆开关条件
  -> 尚未完全落地为精确裁剪规则
```

### 8.9 记忆与前端历史消息的边界

记忆与前端传入的 `request.messages` 是两条不同链路：

```text
request.messages
  -> 本次请求显式带来的上下文

ChatMemory
  -> 系统按 conversationId 自动补回的历史上下文
```

因此如果前端已经自己传入完整历史，同时后端记忆也开启，则可能产生上下文重复。

### 8.10 当前实现特点

当前记忆能力的特点是：

- 基于 `conversationId` 做跨请求会话持久化
- 底层基于 Redis
- 通过 advisor 注入，不直接参与 `buildMessages(...)`
- 当前读取裁剪逻辑仍有待完善

## 9. 工具能力统一编排补充

虽然插件、MCP、组件各自实现不同，但进入 `BasicAgent` 后，会统一进入：

- `CompositeToolCallbackProvider`
- `ToolCallingManager`

其中 `CompositeToolCallbackProvider` 负责：

1. 收集插件 tools
2. 收集 MCP tools
3. 收集 agent components
4. 收集 workflow components
5. 转成统一 `ToolCallback[]`
6. 处理重名工具去重

因此它是“多来源工具统一装配器”。

统一装配后的整体关系可表示为：

```text
插件 / MCP / 组件
  -> 各自 ToolCallback
  -> CompositeToolCallbackProvider
  -> ToolCallback[]
  -> chatOptions
  -> ToolCallingManager
```

## 10. 当前结论

基于当前代码，可以把这些相关功能的实现方式概括为：

- 插件：平台内 OpenAPI/HTTP 能力接入层
- MCP：外部 MCP server 的发现与调用转发层
- 组件：平台内部已发布应用能力复用层
- 知识库：调用模型前的检索增强层
- 模板与模板变量：system prompt 的动态渲染层
- 记忆：跨请求会话上下文持久化层

进一步说：

```text
插件 / MCP / 组件
  -> 解决“模型能调用什么”

知识库 / 模板变量 / 记忆
  -> 解决“模型在调用前能看到什么上下文”
```

这也是 `BasicAgent` 当前功能装配的总体结构。
