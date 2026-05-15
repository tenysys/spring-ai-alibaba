# BasicAgent属性详情

## 1. 说明

本文档用于汇总：

- `BasicAgent实现详情.md`
- `BasicAgent相关功能实现详情.md`

中涉及到的**实体、属性、配置对象以及相关数据表结构**。

本文档重点回答三个问题：

1. `BasicAgent` 相关功能依赖哪些实体对象
2. 这些对象分别有哪些关键属性
3. 这些属性落在哪些表、哪些 JSON 配置、哪些运行时对象中

需要先明确一点：

- `BasicAgent` 本身不是单独一张表
- 它本质上是 `application` 表中 `type = BASIC` 的一类应用

## 2. 总体结构

从数据承载方式看，`BasicAgent` 相关属性主要分三层：

```text
数据库表
  -> 保存应用、版本、插件、MCP、组件、知识库、Provider 等主数据

JSON配置对象
  -> 保存 BasicAgent 版本配置、插件/组件/知识库内部配置

运行时请求对象
  -> 保存本次调用时的 messages、promptVariables、extraParams、conversationId
```

可进一步概括为：

```text
AppEntity / AppVersionEntity
  -> 决定 BasicAgent 是什么、有哪些版本、当前用哪份配置

AgentConfig
  -> 决定 BasicAgent 运行时有哪些功能能力

Plugin / MCP / Component / KB / Provider 相关实体
  -> 决定这些能力各自从哪里来、如何执行
```

## 3. BasicAgent主实体与表结构

### 3.1 `AppEntity`

对应表：

- `application`

定位：

- 表示一个应用主实体
- `BasicAgent` 在持久化层首先就是一条 `application` 记录

核心属性：

- `id`：主键
- `workspaceId`：工作空间 ID
- `appId`：应用业务 ID
- `type`：应用类型，`BasicAgent` 对应 `BASIC`
- `status`：应用状态，如 `DRAFT`、`PUBLISHED_EDITING`
- `name`：应用名称
- `description`：应用描述
- `icon`：应用图标
- `source`：来源
- `gmtCreate` / `gmtModified`
- `creator` / `modifier`

非持久化运行时挂载属性：

- `latestVersion`：最新版本对象，不落表
- `publishedVersion`：当前发布版本对象，不落表

可理解为：

```text
application
  -> 保存“这个 BasicAgent 是谁”
  -> 不保存完整运行配置
```

### 3.2 `AppVersionEntity`

对应表：

- `application_version`

定位：

- 表示某个应用的一个版本快照
- 真正保存 `BasicAgent` 配置 JSON

核心属性：

- `id`：主键
- `workspaceId`
- `appId`
- `status`：该版本状态
- `config`：版本配置 JSON
- `version`：版本号
- `description`：版本描述
- `gmtCreate` / `gmtModified`
- `creator` / `modifier`

关键点：

- `BasicAgent` 的完整能力配置保存在 `config`
- `config` 会反序列化成 `AgentConfig`

可理解为：

```text
application_version
  -> 保存“这个 BasicAgent 某一版怎么运行”
```

## 4. BasicAgent配置对象

### 4.1 `AgentConfig`

载体来源：

- `application_version.config`

定位：

- `BasicAgent` 的核心运行配置结构

顶层属性：

- `modelProvider`
- `model`
- `modalityType`
- `instructions`
- `memory`
- `parameter`
- `tools`
- `mcpServers`
- `agentComponents`
- `workflowComponents`
- `promptVariables`
- `fileSearch`
- `prologue`

### 4.2 `AgentConfig.Parameter`

定位：

- 模型调用参数配置

属性：

- `maxTokens`
- `temperature`
- `topP`
- `repetitionPenalty`

### 4.3 `AgentConfig.Memory`

定位：

- 记忆配置

属性：

- `dialogRound`

### 4.4 `AgentConfig.Tool`

定位：

- 引用插件工具

属性：

- `id`：工具 ID
- `type`：工具类型

### 4.5 `AgentConfig.McpServer`

定位：

- 引用 MCP Server

属性：

- `id`：server code
- `type`

### 4.6 `AgentConfig.PromptVariable`

定位：

- 提示词变量定义

属性：

- `name`
- `type`
- `description`
- `defaultValue`

### 4.7 `AgentConfig.Prologue`

定位：

- 前端欢迎语 / 引导信息

属性：

- `prologueText`
- `suggestedQuestions`

## 5. 模型相关实体与属性

### 5.1 `ProviderEntity`

对应表：

- `provider`

定位：

- 保存模型 provider 配置
- `modelProvider` 最终会指向这类 provider 配置

核心属性：

- `id`
- `workspaceId`
- `icon`
- `name`
- `description`
- `provider`：provider code
- `enable`
- `protocol`：默认 `openai`
- `source`
- `supportedModelTypes`
- `credential`：provider 凭证 JSON
- `gmtCreate` / `gmtModified`
- `creator` / `modifier`

其中 `credential` 最关键，运行时会反序列化为 `ModelCredential`。

### 5.2 `ModelCredential`

载体来源：

- `provider.credential`

定位：

- 模型凭证配置对象

属性：

- `endpoint`
- `apiKey`
- `completionsPath`
- `embeddingsPath`

关键点：

- `apiKey` 在表里通常是加密存储
- 运行时读取时会解密

### 5.3 `ModelEntity`

对应表：

- `model`

定位：

- 保存模型元数据
- 属于 provider 侧模型资源描述

核心属性：

- `id`
- `workspaceId`
- `icon`
- `name`
- `modelId`
- `provider`
- `type`
- `enable`
- `tags`
- `mode`
- `source`
- `gmtCreate` / `gmtModified`
- `creator` / `modifier`

说明：

- `AgentConfig.model` 运行时用的是模型名
- `model` 表更偏向模型中心/模型管理侧元数据

## 6. 插件相关实体与属性

### 6.1 `PluginEntity`

对应表：

- `plugin`

定位：

- 表示插件主对象

核心属性：

- `id`
- `workspaceId`
- `pluginId`
- `type`
- `status`
- `name`
- `description`
- `config`
- `source`
- `gmtCreate` / `gmtModified`
- `creator` / `modifier`

其中：

- `config` 保存插件级配置 JSON

### 6.2 `Plugin`

载体来源：

- `plugin.config` 反序列化后的运行时对象

顶层属性：

- `pluginId`
- `name`
- `description`
- `config`
- `source`
- `extension`
- `gmtCreate` / `gmtModified`

### 6.3 `Plugin.PluginConfig`

定位：

- 插件级 HTTP/OpenAPI 配置

属性：

- `schemeVersion`
- `server`
- `headers`
- `auth`

### 6.4 `Plugin.ApiAuth`

定位：

- 插件鉴权配置

属性：

- `type`
- `authorizationPosition`
- `authorizationType`
- `authorizationKey`
- `authorizationValue`

### 6.5 `ToolEntity`

对应表：

- `tool`

定位：

- 插件下的具体工具

核心属性：

- `id`
- `toolId`
- `pluginId`
- `workspaceId`
- `status`
- `enabled`
- `testStatus`
- `name`
- `description`
- `config`
- `apiSchema`
- `gmtCreate` / `gmtModified`
- `creator` / `modifier`

其中：

- `config` 保存工具执行配置 JSON
- `apiSchema` 保存工具 API schema 文本

### 6.6 `Tool`

运行时对象属性：

- `pluginId`
- `toolId`
- `plugin`
- `name`
- `description`
- `config`
- `apiSchema`
- `enabled`
- `testStatus`
- `status`
- `gmtCreate` / `gmtModified`
- `allToolParam`

### 6.7 `Tool.ToolConfig`

定位：

- 工具级请求配置

属性：

- `path`
- `server`
- `requestMethod`
- `contentType`
- `inputParams`
- `outputParams`
- `examples`

## 7. MCP相关实体与属性

### 7.1 `McpServerEntity`

对应表：

- `mcp_server`

定位：

- 表示 MCP Server 主记录

核心属性：

- `id`
- `gmtCreate` / `gmtModified`
- `serverCode`
- `name`
- `description`
- `source`
- `deployEnv`
- `type`
- `deployConfig`
- `workspaceId`
- `accountId`
- `status`
- `bizType`
- `detailConfig`
- `host`
- `installType`

关键字段说明：

- `serverCode`：`AgentConfig.mcpServers[].id` 最终引用的标识
- `deployConfig`：部署配置 JSON
- `detailConfig`：详情配置 JSON

### 7.2 MCP运行时关键对象

虽然当前实体表里存的是 `McpServerEntity`，但执行链中还会出现：

- `McpServerDetail`
- `McpTool`
- `McpServerCallToolRequest`
- `McpServerCallToolResponse`

这些对象主要服务于：

- 暴露 MCP tools
- 执行 MCP tool call

它们属于运行时协议对象，不直接对应单独数据表。

## 8. 组件相关实体与属性

### 8.1 `AppComponentEntity`

对应表：

- `application_component`

定位：

- 表示发布后的组件主记录

核心属性：

- `id`
- `gmtCreate` / `gmtModified`
- `code`
- `name`
- `workspaceId`
- `type`
- `appId`
- `config`
- `description`
- `status`
- `creator`
- `modifier`
- `needUpdate`

关键字段说明：

- `code`：组件唯一调用标识
- `appId`：组件源应用 ID
- `type`：Agent 或 Workflow
- `config`：组件输入输出映射 JSON
- `needUpdate`：源应用更新后是否需要刷新组件

### 8.2 `AppComponentConfig`

载体来源：

- `application_component.config`

定位：

- 组件输入输出适配配置

顶层属性：

- `input`
- `output`

### 8.3 `AppComponentConfig.Input`

属性：

- `userParams`
- `systemParams`

### 8.4 `AppComponentConfig.UserParams`

属性：

- `code`
- `name`
- `params`

### 8.5 `AppComponentConfig.Params`

定位：

- 组件参数定义

属性：

- `field`
- `description`
- `type`
- `required`
- `display`
- `defaultValue`
- `alias`
- `source`

说明：

- `alias` 用于前端/组件调用侧字段映射
- `defaultValue` 用于缺省填充
- `source` 用于区分参数值来源

## 9. 知识库相关实体与属性

### 9.1 `KnowledgeBaseEntity`

对应表：

- `knowledge_base`

定位：

- 知识库主记录

核心属性：

- `id`
- `kbId`
- `workspaceId`
- `type`
- `status`
- `name`
- `description`
- `processConfig`
- `indexConfig`
- `searchConfig`
- `totalDocs`
- `gmtCreate` / `gmtModified`
- `creator` / `modifier`

关键字段说明：

- `processConfig`：文档处理配置 JSON
- `indexConfig`：索引配置 JSON
- `searchConfig`：检索配置 JSON

### 9.2 `KnowledgeBase`

运行时对象属性：

- `kbId`
- `type`
- `status`
- `name`
- `description`
- `processConfig`
- `indexConfig`
- `searchConfig`
- `totalDocs`
- `gmtCreate` / `gmtModified`
- `creator` / `modifier`
- `workspaceId`

说明：

- 运行时对象会把表里的 JSON 字段反序列化成结构化对象

### 9.3 `FileSearchOptions`

定位：

- `AgentConfig.fileSearch`
- 也是 `KnowledgeBase.searchConfig` 的重要结构

属性：

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

说明：

- `BasicAgent` 层的 `fileSearch.kbIds` 决定本次调用会查询哪些知识库
- 知识库自身 `searchConfig` 更偏向知识库默认检索配置

### 9.4 `DocumentEntity`

对应表：

- `document`

定位：

- 知识库内文档主记录

核心属性：

- `id`
- `workspaceId`
- `kbId`
- `docId`
- `status`
- `type`
- `enabled`
- `name`
- `format`
- `size`
- `metadata`
- `indexStatus`
- `path`
- `parsedPath`
- `processConfig`
- `source`
- `error`
- `gmtCreate` / `gmtModified`
- `creator` / `modifier`

关键字段说明：

- `kbId`：所属知识库
- `metadata`：文档元数据 JSON
- `indexStatus`：索引状态
- `path` / `parsedPath`：原文件路径与解析后路径

## 10. 模板与变量相关属性

### 10.1 `instructions`

所在对象：

- `AgentConfig.instructions`

定位：

- `BasicAgent` 的系统提示词模板

说明：

- 若不开启知识库，它会直接渲染为 `SystemMessage`
- 若开启知识库，它会作为带 `{documents}` 占位符的模板参与二次渲染

### 10.2 `promptVariables`

所在对象：

- `AgentConfig.promptVariables`
- `AgentRequest.promptVariables`

两层含义：

```text
AgentConfig.promptVariables
  -> 保存变量定义 + 默认值

AgentRequest.promptVariables
  -> 保存本次请求的覆盖值
```

### 10.3 `AgentRequest`

定位：

- `BasicAgent` 本次调用请求对象

核心属性：

- `appId`
- `conversationId`
- `messages`
- `stream`
- `promptVariables`
- `extraPrams`
- `draft`

关键点：

- `promptVariables` 是模板变量最终值的重要运行时入口
- `extraPrams` 是插件/MCP/组件工具参数补充入口

## 11. 记忆相关属性

### 11.1 `AgentConfig.memory.dialogRound`

定位：

- `BasicAgent` 记忆配置参数

当前实现作用：

- 作为是否开启记忆的判断条件之一

### 11.2 会话标识属性

记忆运行时最关键的属性是：

- `AgentRequest.conversationId`

运行时实际使用的会话 key 还会叠加：

- `appId + "_" + conversationId`

### 11.3 持久化位置

记忆没有独立数据库表。

当前实现中：

- 配置参数落在 `application_version.config -> AgentConfig.memory`
- 具体历史消息落在 Redis `ChatMemory`

因此记忆的数据承载方式是：

```text
数据库
  -> 保存记忆配置

Redis
  -> 保存会话消息历史
```

## 12. 属性与表的对应关系总览

### 12.1 BasicAgent主链路

```text
application
  -> AppEntity
  -> 保存应用主信息

application_version
  -> AppVersionEntity
  -> config(JSON)
  -> AgentConfig
```

### 12.2 模型

```text
provider
  -> ProviderEntity
  -> credential(JSON)
  -> ModelCredential

model
  -> ModelEntity
```

### 12.3 插件

```text
plugin
  -> PluginEntity
  -> config(JSON)
  -> Plugin / PluginConfig

tool
  -> ToolEntity
  -> config(JSON)
  -> Tool / ToolConfig
```

### 12.4 MCP

```text
mcp_server
  -> McpServerEntity
  -> deployConfig/detailConfig(JSON)
```

### 12.5 组件

```text
application_component
  -> AppComponentEntity
  -> config(JSON)
  -> AppComponentConfig
```

### 12.6 知识库

```text
knowledge_base
  -> KnowledgeBaseEntity
  -> process/index/search config(JSON)
  -> KnowledgeBase

document
  -> DocumentEntity
```

### 12.7 运行时请求

```text
AgentRequest
  -> messages
  -> promptVariables
  -> extraPrams
  -> conversationId
```

## 13. 当前结论

从属性承载角度看，`BasicAgent` 相关数据可以总结为：

- `application`：保存应用主属性
- `application_version`：保存版本配置 JSON
- `AgentConfig`：保存 `BasicAgent` 功能配置
- `provider / model`：保存模型侧属性与凭证
- `plugin / tool`：保存插件与工具定义
- `mcp_server`：保存 MCP server 定义
- `application_component`：保存组件包装配置
- `knowledge_base / document`：保存知识库与文档属性
- `AgentRequest`：保存本次调用请求属性
- `Redis ChatMemory`：保存会话级历史消息

进一步说：

```text
谁是 BasicAgent
  -> AppEntity

BasicAgent 某一版如何运行
  -> AppVersionEntity.config
  -> AgentConfig

BasicAgent 运行时依赖什么资源
  -> provider / plugin / tool / mcp_server / application_component / knowledge_base

BasicAgent 本次调用带什么上下文
  -> AgentRequest + Redis memory
```

这就是当前 `BasicAgent` 相关属性、实体与表结构的整体图谱。
