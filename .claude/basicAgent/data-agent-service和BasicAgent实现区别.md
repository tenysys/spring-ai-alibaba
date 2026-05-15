# data-agent-service和BasicAgent实现区别

## 1. 说明

本文档用于对比：

- `BasicAgent`
- `data-agent-service` 中的 `common`、`framework`、`capability-component` 三个模块

重点比较二者在功能覆盖范围、实现层次、运行时职责和核心实现方式上的区别。

需要先明确一个前提：

```text
BasicAgent
  -> 是上层 Agent 应用执行与编排框架

data-agent-service 三模块
  -> 是下层能力服务与资源治理底座
```

因此二者不是同层替代关系，而是明显的上下层关系。

## 2. 总体区别

`BasicAgent` 的核心关注点是：

- 如何定义一个 Agent 应用
- 如何保存与发布该 Agent 的配置版本
- 如何在一次请求中装配模型、Prompt、记忆、知识库、工具、MCP、组件
- 如何执行工具调用、流式输出和最终响应转换

`data-agent-service` 三模块的核心关注点是：

- 如何提供模型、Embedding、向量存储等基础运行时能力
- 如何管理数据源、数据库连接、SQL 执行与资源绑定
- 如何提供知识库、向量检索、Dify 接入等后端能力
- 如何把这些能力装配成可供上层复用的服务

可以概括为：

```text
BasicAgent = “怎么组装并执行一个 Agent 应用”

data-agent-service = “给 Agent 提供哪些底层能力服务”
```

## 3. 对比矩阵

| 功能项 | BasicAgent | data-agent-service 三模块 | 实现区别 |
|---|---|---|---|
| 整体定位 | Agent 应用执行与编排层 | 底层能力服务与资源治理层 | `BasicAgent` 负责“怎么运行一个 Agent”，三模块负责“给 Agent 提供什么能力” |
| 配置承载 | `AgentConfig` + `AppVersionEntity.config` | Spring `properties` + 数据库实体 + DTO | `BasicAgent` 以应用版本配置为中心；三模块以基础配置和业务实体为中心 |
| 版本控制 | 有完整版本体系：`AppEntity`、`AppVersionEntity`、`latest/published` | 无对应的 Agent 应用版本体系 | `BasicAgent` 是可发布应用；三模块是服务模块 |
| 模型管理 | 应用级 `modelProvider`、`model`、`parameter` | 平台级激活模型配置、`AiModelRegistry`、`DynamicModelFactory` | 前者按应用选择模型，后者提供全局模型能力 |
| ChatModel 装配 | `BasicAgentExecutor` 按本次请求装配 | `DynamicModelFactory` + `AiModelRegistry` + Spring Bean 装配 | 前者面向单次执行，后者面向平台运行时复用 |
| EmbeddingModel | 作为知识库/检索能力的依赖被消费 | 由 `framework` 动态代理装配为全局 Bean | 三模块在 Embedding 基础设施上更完整 |
| Prompt/Instructions | 核心能力，`instructions` 直接参与系统提示词构建 | 不以 Prompt 编排为核心 | `BasicAgent` 强调 LLM 上下文组织，三模块强调能力提供 |
| Prompt Variables | 有完整变量定义、默认值、请求覆盖逻辑 | 无对应顶层机制 | `BasicAgent` 有模板渲染体系，三模块没有这一层抽象 |
| Memory | 有 `memory` 配置、`conversationId`、`ChatMemory`、Advisor | 三模块未体现 Agent 会话记忆机制 | `BasicAgent` 有跨请求对话记忆，三模块没有完整 Agent 记忆层 |
| 知识库接入 | 作为 `fileSearch`，在模型调用前增强 Prompt | 作为独立能力：向量检索、Dify 检索、数据集访问 | 前者是上下文增强，后者是后端服务能力 |
| 向量检索 | 被 Agent 调用链消费 | `VectorStoreService` 提供入库、检索、删除、混合检索 | 三模块对向量能力实现更底层、更完整 |
| 混合检索 | 文档中主要体现“检索能力接入” | 明确实现 `HybridRetrievalStrategy`、融合策略 | 三模块在检索策略层更具体 |
| 文档元数据治理 | 主要从 Agent 使用角度消费 | 明确校验 `agentId`、`vectorType`、`resourceId` 等元数据 | 三模块更偏存储治理 |
| MCP | 作为 Agent 工具能力接入 `ToolCallback` | 有 `McpController`，但未体现完整 LLM tool-call 编排 | `BasicAgent` 更强调运行时调用链 |
| 插件/OpenAPI 工具 | 有完整 ToolCallback、参数合并、执行链 | 三模块未体现同等级插件执行框架 | 插件体系是 `BasicAgent` 更强的能力 |
| Agent/Workflow 组件 | 支持作为组件复用并进入 tool-call | 三模块没有对应应用组件编排层 | 组件化复用是 `BasicAgent` 的上层能力 |
| Tool Calling | 有递归 tool call、二次模型调用、流式/非流式分支 | 三模块没有完整 LLM 工具递归执行器 | `BasicAgent` 更像 Agent runtime |
| 流式输出 | 有明确流式执行链 | Dify SSE 转 Graph 流是局部能力，不是通用 Agent 输出链 | `BasicAgent` 是通用流式 Agent 执行；三模块是某能力的流式适配 |
| 数据源管理 | 无完整数据源治理体系 | `DatasourceController/Service/HandlerFactory` 完整实现 | 三模块更偏业务资源平台 |
| 多数据库支持 | 文档未体现 | MySQL / Oracle / PostgreSQL / 达梦连接器 | 三模块在数据库适配层明显更强 |
| SQL 执行 | 无专门 SQL 执行层 | `SqlExecutor` 负责 schema 切换、执行、恢复 | 三模块具备独立数据访问执行能力 |
| 元数据/关系/语义 | 不属于核心主线 | 有表、字段、关系、语义、全景等实体与服务 | 三模块更偏数据治理平台 |
| 外部系统集成 | 聚焦模型、插件、MCP、知识库能力编排 | 直接集成 Dify、向量库、数据库、Nacos/Sophic 周边 | 三模块更偏后端集成层 |
| Spring 基础设施 | 主要消费平台已有基础设施 | `framework` 提供线程池、属性绑定、AOP、默认 VectorStore | 三模块自己包含基础设施层 |
| 主要抽象中心 | `Application` / `AgentConfig` / `BasicAgentExecutor` | `ModelRegistry` / `CapabilityConfig` / `DatasourceService` / `VectorStoreService` | 前者以 Agent 应用为中心，后者以能力服务为中心 |

## 4. 分层差异

### 4.1 `BasicAgent` 的层次

`BasicAgent` 更接近一个应用层执行框架，核心层次是：

```text
应用实体层
  -> AppEntity / AppVersionEntity

配置模型层
  -> AgentConfig

运行时执行层
  -> BasicAgentExecutor

增强能力层
  -> tools / mcp / components / fileSearch / memory
```

它最重要的事情是把“应用配置”装配成“一次真实的 Agent 执行”。

### 4.2 `data-agent-service` 三模块的层次

`data-agent-service` 三模块更接近能力服务架构，核心层次是：

```text
基础公共层
  -> common

运行时装配层
  -> framework

业务能力实现层
  -> capability-component
```

它最重要的事情是把“模型、数据源、检索、知识库”等能力做成可复用后端服务。

## 5. 关键差异展开

### 5.1 版本与配置模型

`BasicAgent` 里最核心的是：

- `AppEntity`
- `AppVersionEntity`
- `AgentConfig`

也就是说，它天然把 Agent 当成一个“可版本化应用”。

而 `data-agent-service` 三模块里没有对应的应用版本体系。  
它们更多是：

- 模型配置实体
- 数据源实体
- 知识库 DTO
- 向量服务配置
- Spring 配置类

区别可以写成：

```text
BasicAgent
  -> 先有“应用配置版本”
  -> 再有运行时执行

data-agent-service
  -> 先有“基础能力服务”
  -> 由上层决定如何组合使用
```

### 5.2 模型能力的实现层次

`BasicAgent` 中模型能力是应用配置的一部分：

- `modelProvider`
- `model`
- `parameter`

重点是“这次 Agent 调用用什么模型”。

`data-agent-service` 中模型能力是平台公共能力的一部分：

- `ModelConfigDataServiceImpl`
- `DynamicModelFactory`
- `AiModelRegistry`
- `framework` 中的动态 `EmbeddingModel` Bean 装配

重点是“平台当前如何提供全局模型访问能力”。

所以二者虽然都涉及模型，但抽象层次不同：

```text
BasicAgent：请求级 / 应用级模型选择
data-agent-service：平台级模型供给与实例管理
```

### 5.3 知识库能力的实现差异

`BasicAgent` 中知识库能力主要通过：

- `fileSearch`
- `DocumentRetriever`
- `KnowledgeBaseRetrievalAdvisor`

本质是：

- 在调用模型前，给 Prompt 注入检索结果

`data-agent-service` 中知识库相关能力主要分成：

- `VectorStoreService`
- `DifyApiService`

本质是：

- 作为独立能力服务提供检索和外部知识库接入

也就是说：

```text
BasicAgent：知识库是 Prompt 增强机制
data-agent-service：知识库是后端能力服务
```

### 5.4 向量能力的实现差异

`BasicAgent` 文档中，向量能力更多是“被消费”的：

- 用于知识库召回
- 用于增强上下文

`data-agent-service` 中，向量能力是“被实现”的：

- 文档写入
- 元数据校验
- 混合检索
- 过滤删除
- SimpleVectorStore 兼容删除

所以：

```text
BasicAgent：调用检索能力
data-agent-service：实现检索能力
```

### 5.5 MCP 与工具能力的实现差异

`BasicAgent` 中：

- MCP、插件、组件都被统一纳入 `ToolCallback`
- 支持模型发起 tool call
- 支持递归调用和二次模型调用

`data-agent-service` 中：

- 有 `McpController`
- 但没有在这三个模块里看到一套等价的通用 Agent tool-calling 执行器

所以：

```text
BasicAgent：MCP/工具是 Agent runtime 的一部分
data-agent-service：MCP 更像平台能力接口或资源侧能力
```

### 5.6 记忆能力的实现差异

`BasicAgent` 中记忆能力是完整闭环：

- `memory.dialogRound`
- `conversationId`
- `ChatMemory`
- `MessageChatMemoryAdvisor`

`data-agent-service` 三模块中未体现同等级的对话记忆执行链。

这说明：

- `BasicAgent` 已经进入“对话型 Agent 产品运行时”层面
- `data-agent-service` 还停留在“能力服务底座”层面

### 5.7 数据源与 SQL 能力的实现差异

这是二者最明显的区别之一。

`BasicAgent` 文档中没有专门的数据源治理和 SQL 执行层。  
而 `data-agent-service` 中有完整链路：

- `DatasourceController`
- `DatasourceService`
- `DatasourceCapabilityHandlerFactory`
- 多数据库连接器
- `SqlExecutor`

这意味着三模块已经具备独立的数据资源平台能力，而 `BasicAgent` 本身并不承担这一层职责。

## 6. 能力覆盖差异总结

### 6.1 `BasicAgent` 更强的部分

`BasicAgent` 明显更完整覆盖了以下上层 Agent 运行能力：

- 应用版本管理
- 发布/草稿态切换
- Agent 顶层配置模型
- Prompt 模板变量体系
- 对话记忆
- Tool calling 递归执行
- 流式输出执行链
- Agent/Workflow 组件复用

### 6.2 `data-agent-service` 更强的部分

`data-agent-service` 三模块明显更完整覆盖了以下底层能力：

- 模型注册与运行时实例管理
- Spring 基础设施装配
- 多数据库适配
- SQL 执行与 schema 切换
- 数据源管理与资源绑定
- 向量文档治理
- 混合检索与融合策略
- Dify 数据集与流式能力接入
- 元数据、关系、语义、全景类资源能力

## 7. 关系判断

如果从架构关系看，二者更适合这样理解：

```text
BasicAgent
  -> 上层 Agent 应用框架
  -> 关注“如何把能力编排成一次智能体运行”

data-agent-service 三模块
  -> 下层能力服务底座
  -> 关注“如何把模型、数据源、知识库、检索做成可复用能力”
```

所以它们不是平行竞争关系，而是更像：

```text
BasicAgent 可以消费类似 data-agent-service 这样的能力服务
data-agent-service 也可以作为 BasicAgent 背后的能力实现底座
```

## 8. 结论

最终可以把二者的实现区别压缩成两句话：

`BasicAgent` 是上层 Agent 应用框架，负责配置、版本、Prompt、记忆、工具调用和运行时编排。  
`data-agent-service` 的 `common`、`framework`、`capability-component` 是下层能力底座，负责模型、向量、数据源、知识库和资源治理等基础服务。

如果进一步抽象：

```text
BasicAgent 解决“Agent 怎么运行”

data-agent-service 解决“Agent 运行时可依赖哪些底层能力”
```

