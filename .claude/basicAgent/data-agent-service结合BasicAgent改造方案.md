# data-agent-service结合BasicAgent改造方案

## 1. 说明

本文档用于回答一个具体问题：

```text
如果要在 data-agent-service 中实现“通用智能体（BasicAgent 类能力）”，
结合当前 data-agent-service 三个模块已有能力，
哪些内容可以直接迁移 BasicAgent，
哪些内容需要对 data-agent-service 现有能力进行改造，
哪些内容可以直接复用 data-agent-service 当前实现？
```

本文档中的 `data-agent-service` 主要指以下三个模块：

- `common`
- `framework`
- `capability-component`

对照参考对象主要包括：

- `BasicAgent实现详情.md`
- `BasicAgent相关功能实现详情.md`
- `BasicAgent属性详情.md`
- `BasicAgent功能配置说明.md`
- `通用智能体功能设计.md`

## 1.1 核心约束

本次改造必须满足一个前提：

```text
data-agent-service 的 common / framework / capability-component
中现有对外接口已经被其他模块调用，
改造必须兼容旧接口，不能影响当前使用方。
```

这意味着本次改造不是：

- 直接重写现有接口
- 直接替换现有服务语义
- 直接调整已有返回结构
- 直接把旧调用链改造成通用智能体调用链

而应该是：

- 在现有能力之上增加新的通用智能体层
- 对现有服务做非破坏式扩展
- 通过适配层、包装层、新接口和新增配置承载改造
- 保证原有模块调用路径保持可用

## 2. 总体判断

先给结论：

`data-agent-service` 当前已经具备“通用智能体底座”的一大部分基础能力，但还不具备一个完整的 `BasicAgent` 运行框架。

它现在更像：

```text
模型能力 + 向量能力 + 数据源能力 + Dify能力 + 资源治理能力
```

而 `BasicAgent` 需要的是：

```text
应用模型
  + 版本管理
  + 统一配置模型
  + 请求执行器
  + Prompt装配
  + 记忆
  + 工具调用编排
  + 上下文增强
```

因此改造方向不应是“把 BasicAgent 全量硬拷贝过来”，而应是：

```text
复用 data-agent-service 已有底层能力
  + 迁移 BasicAgent 上层运行框架
  + 在接口边界上做适配
```

同时必须遵守：

```text
旧接口保持兼容
新能力优先通过新增接口、新服务、新适配层接入
```

## 3. 建议的总体架构

建议最终形成如下分层：

```text
BasicAgent应用层
  -> Agent应用实体、版本、配置、发布与调试

BasicAgent运行时层
  -> 请求对象、执行器、Prompt组装、工具调用、流式输出

能力接入层
  -> 适配 data-agent-service 的模型、知识库、向量、数据源、MCP 等能力

data-agent-service底层能力层
  -> common / framework / capability-component
```

也就是说：

- `BasicAgent` 相关内容主要补“上面两层”
- `data-agent-service` 现有三模块主要承担“下面两层”

并且在实现方式上建议采用：

```text
旧能力层
  -> 保持现有接口不动

新智能体层
  -> 通过 adapter / facade / executor 组合旧能力
```

## 4. 可直接迁移的 BasicAgent 内容

这一类能力，`data-agent-service` 当前明显缺失，且其设计本质属于上层 Agent 运行框架，适合直接参考或迁移 `BasicAgent` 现有实现思路。

### 4.1 应用与版本模型

建议直接迁移或高度参考的内容：

- `AppEntity`
- `AppVersionEntity`
- 应用状态管理
- `latestVersion / publishedVersion`
- 草稿/发布态切换逻辑

原因：

- `data-agent-service` 当前没有“通用智能体”自己的应用主模型
- 也没有“配置版本快照”体系
- 但这是通用智能体产品化管理的前提

如果不迁移这部分，后续会缺：

- 调试与正式运行分离
- 发布态稳定性
- 配置回溯
- 智能体版本审计

### 4.2 `AgentConfig` 顶层配置模型

建议直接迁移或高度参考：

- `AgentConfig`
- `memory`
- `parameter`
- `promptVariables`
- `knowledge`
- `tools`
- `mcpServers`
- `agentComponents`
- `workflowComponents`
- `prologue`
- 后续扩展的 `skills`

原因：

- `data-agent-service` 当前有很多能力，但缺一个统一的“智能体配置入口”
- 这些能力现在散落在数据源、向量、模型配置、控制器等不同位置
- 缺一个面向智能体运行时的统一配置视图

建议做法：

- 保留 `BasicAgent` 的顶层配置思路
- 但在字段定义上做面向 `data-agent-service` 的适配

例如：

- `knowledge` 建议直接建模为 Dify 知识配置
- `tools` 中要扩展数据源工具/语义工具/能力组件工具
- `skills` 应该作为新的上下文增强项加入

注意：

- 不建议把 `AgentConfig` 直接塞入现有数据源、向量、知识服务接口
- 应由新的通用智能体服务层消费 `AgentConfig`
- 再由该服务层去调用旧接口

### 4.3 请求与响应模型

建议迁移：

- `AgentRequest`
- `AgentResponse`
- `AgentContext`
- 消息结构
- 多模态消息结构

原因：

- `data-agent-service` 当前没有一个面向通用智能体的标准请求/响应协议
- 当前各能力服务有自己的 DTO，但无法直接组成统一 Agent 调用协议

### 4.4 `BasicAgentExecutor`

这是最值得迁移的核心实现之一。

建议迁移或高度参考的能力包括：

- `execute(...)`
- `streamExecute(...)`
- `buildMessages(...)`
- `buildInstructions(...)`
- `buildChatClient(...)`
- `convertResponse(...)`
- 工具递归调用逻辑

原因：

- `data-agent-service` 当前没有通用智能体执行器
- 现有 `common.LlmService` 只能做基础 LLM 调用
- 不能处理完整的 Agent 编排链

兼容性要求：

- 不要修改现有 `LlmService` 的语义以兼容 `BasicAgentExecutor`
- 应在上层新增执行器，并把 `LlmService` 视为基础调用能力或回退能力

### 4.5 Tool calling 编排体系

建议迁移：

- `ToolCallingManager`
- `CompositeToolCallbackProvider`
- 各类 `ToolCallback`

原因：

- `data-agent-service` 当前虽然有能力资源，但没有统一的“模型可调用工具层”
- 这是让通用智能体从“能回答”升级到“能执行”的关键

### 4.6 记忆执行链

建议迁移：

- `memoryEnabled(...)`
- `MessageChatMemoryAdvisor`
- `conversationId` 规则
- 会话上下文装配机制

原因：

- `data-agent-service` 当前没有完整会话记忆层
- 通用智能体必须具备短期记忆
- 长期记忆可先设计为扩展点，短期记忆应优先落地

### 4.7 Prompt 模板变量体系

建议迁移：

- `promptVariables` 的定义方式
- 默认值 + 请求覆盖值机制
- 基于 `SystemPromptTemplate` 的渲染思路

原因：

- `data-agent-service` 现在能做模型调用，但没有面向智能体的模板参数化体系
- 这会直接影响通用智能体的可配置性与复用性

## 5. 需要对 data-agent-service 现有能力进行改造的内容

这一类不是简单迁移或简单复用，而是要在已有实现基础上加一层适配或抽象。

### 5.1 模型能力需要从“全局激活模型”改造为“智能体可选模型”

当前 `data-agent-service` 模型层的特点是：

- `AiModelRegistry` 读取当前激活模型
- `DynamicModelFactory` 创建全局 `ChatModel` / `EmbeddingModel`
- 偏平台级单实例使用方式

而 `BasicAgent` 的模型层特点是：

- 每个智能体可以配置自己的 `modelProvider` 和 `model`
- 每次请求按智能体配置装配

所以需要改造：

```text
当前：
  平台全局激活模型 -> 通用调用

目标：
  智能体配置模型 -> 按请求装配 ChatModel / ChatOptions
```

建议做法：

- 保留 `DynamicModelFactory`
- 弱化“只读当前激活模型”的耦合
- 新增按 `AgentConfig` 或 `ModelConfigDTO` 直接构建 `ChatClient` / `ChatModel` 的入口
- `AiModelRegistry` 可保留为默认模型回退机制，而不是唯一入口

兼容性要求：

- 不要移除 `AiModelRegistry.getChatClient(...)`、`getEmbeddingModel()` 的现有行为
- 旧模块仍然按“当前激活模型”工作
- 新增“按智能体配置构建模型”的并行入口

### 5.2 向量检索能力要从“后端服务接口”改造为“Agent 可复用底层检索能力”

当前 `VectorStoreService` 的定位是：

- 文档管理与检索服务
- 面向后端业务层接口

而通用智能体后续仍然会使用向量能力，但不建议再把它等同于“知识库检索能力”。

当前更合理的边界是：

- 知识库检索：只走 Dify
- 向量检索：用于通用工具能力、长期记忆、资源向量化检索等底层场景

因此这里需要增加的是：

- 面向长期记忆的检索适配层
- 面向通用工具的向量检索适配层

建议做法：

- 保留 `VectorStoreService`
- 不再新增 `fileSearch` 这一层通用知识检索抽象
- 新增面向长期记忆和工具能力的向量检索适配层

兼容性要求：

- 不改动 `VectorStoreService` 现有接口含义
- 不把 Agent 语义硬塞进通用向量服务接口
- Agent 侧只在长期记忆、工具检索等场景消费 `VectorStoreService`

### 5.3 Dify 能力要从“独立服务”改造为“智能体知识配置的唯一知识源”

当前 `DifyApiService` 的定位偏外部服务客户端：

- 查询知识库
- 检索数据集
- 做 SSE 流转

如果当前明确约束为：

```text
知识库只在 Dify 中创建
知识召回只通过 Dify 接口实现
```

那么不建议继续保留 `BasicAgent` 原始语义里的 `fileSearch` 通用抽象。

更合适的做法是：

- 直接将知识能力建模为 `knowledge` 或 `difyKnowledge`
- 其配置只表达 Dify 知识库相关参数

例如：

```text
knowledge
  -> enabled
  -> datasetIds
  -> topK
  -> threshold
  -> rerank
  -> citation
```

这样做的好处是：

- 避免 `fileSearch` 与向量工具能力混淆
- 避免 `fileSearch` 与长期记忆检索混淆
- 明确表达“知识检索只走 Dify”

兼容性要求：

- 保留 `DifyApiService` 作为独立服务
- 不破坏已有直接调用 Dify 服务的模块
- 智能体知识增强直接包装 `DifyApiService` 即可

### 5.4 数据源能力要从“管理对象”改造为“智能体可调用工具”

当前数据源能力主要是：

- `DatasourceController`
- `DatasourceService`
- `SqlExecutor`
- 多数据库连接器

这些能力本身已经很强，但还不是“Agent 工具”。

要让通用智能体使用，需要新增：

- 数据源工具描述
- 表/概念/属性选择配置
- 安全执行边界
- 工具输出结构约定

建议做法：

- 保留数据源服务、连接器和 SQL 执行器
- 新增面向 Agent 的 datasource tool adapter
- 把“数据源 + 允许表/概念 + 允许字段 + 调用规则”封装为工具配置

兼容性要求：

- 不修改 `DatasourceService` 当前 CRUD、测试连接、状态切换等接口语义
- 不让 Agent 专属逻辑侵入现有数据源管理接口
- 通过新工具适配层调用 `DatasourceService`、`SqlExecutor`、元数据服务

### 5.5 MCP 能力要从“资源/接口能力”改造为“可选具体工具”

当前文档设计里已经提出：

- MCP 服务需要支持选定具体工具，默认全选

这意味着对现有 MCP 能力需要加一层配置适配：

- 服务级绑定
- 工具级筛选
- Tool schema 暴露
- Tool call 路由

建议做法：

- 借鉴 `BasicAgent` 的 `mcpServers` 配置思路
- 但在数据结构上支持：
  - 绑定某个 MCP 服务
  - 指定启用哪些工具
  - 默认全选

兼容性要求：

- 若已有模块按“服务级 MCP 能力”调用，则保留原有接口
- 对工具筛选、工具级启用配置，使用新增配置模型和新增解析逻辑承载

### 5.6 资源绑定能力要升级为“智能体装载资源体系”

当前 `capability-component` 已经有资源绑定与资源对象概念，但还是偏资源管理视角。

通用智能体需要的是：

- 智能体装载哪些模型
- 装载哪些知识库
- 装载哪些数据源
- 装载哪些 MCP 工具
- 装载哪些组件
- 装载哪些 SKILL

所以要从：

```text
资源管理
```

升级为：

```text
智能体资源装载模型
```

建议做法：

- 在应用版本配置中统一记录资源挂载关系
- 不直接依赖零散资源表拼运行时状态
- 保持“版本配置快照就是运行依据”

结合当前 `data-agent-service` 的资源绑定实现，建议进一步明确资源绑定模型的职责拆分：

```text
AgentResourceBinding
  -> 承载 agent 与资源实例的绑定关系
  -> 承载资源级参数配置
  -> 承载资源级展示/快照信息

AgentResourceBindingItem
  -> 承载资源下具体绑定的子项内容
```

以不同资源类型举例：

- 数据源：
  - `AgentResourceBinding` 表示绑定哪个数据源
  - `AgentResourceBindingItem` 表示绑定该数据源下哪些表、概念或属性
- MCP：
  - `AgentResourceBinding` 表示绑定哪个 MCP 服务
  - `AgentResourceBindingItem` 表示启用了该服务下哪些 MCP 工具
- 知识库：
  - 只有 `AgentResourceBinding`
  - 当前没有资源子项明细

#### 5.6.1 `metaData` 与 `params` 分离建议

当前资源绑定里 `metaData` 已经承担了一部分扩展信息存储职责，但对于通用智能体改造，不建议继续让“参数配置”和“资源快照”混存在同一个字段中。

建议调整为：

```text
AgentResourceBinding.metaData
  -> 专门存储资源展示快照 / 资源视图信息

AgentResourceBinding.params
  -> 专门存储资源级参数配置
```

这样做的原因是：

- 参数配置和资源快照语义不同
- 参数配置属于运行时配置
- 资源快照属于展示/审计/回显信息
- 混存在一个字段里，后续解析、演进和兼容都会变复杂

建议参数处理方式改为：

```text
request.params
  -> 直接存入 AgentResourceBinding.params

资源展示对象
  -> 序列化后存入 AgentResourceBinding.metaData
```

而不是继续采用：

```text
params 反序列化
  -> 放入 metaData map
  -> 再整体序列化
```

分离后带来的好处：

- 运行时读取参数更直接
- 资源快照回显更稳定
- 后续字段演进更清晰
- 调试态转发布态时，资源配置与资源展示信息可以分别处理

因此，调试态资源配置承载可以更准确地表达为：

```text
业务资源挂载
  -> AgentResourceBinding(resource binding + params + metaData)
  -> AgentResourceBindingItem(具体资源子项)
```

兼容性要求：

- 不破坏 `capability-component` 已有资源管理与资源绑定表结构的既有使用方式
- 新增“智能体装载资源”视角时，优先通过配置快照和适配映射实现
- 不要求所有旧资源先改造成 Agent 原生结构

进一步的兼容性建议：

- 若增加 `AgentResourceBinding.params` 字段，应采用增量方式扩展表结构
- 旧逻辑仍可继续读取 `metaData`
- 新逻辑优先读取 `params` 存放资源级配置
- 对历史数据可采用“无 `params` 时回退旧解析逻辑”的兼容策略

### 5.7 需要新增过滤、日志、监测能力

根据 `通用智能体功能设计.md`，还需要：

- 数据干预
- 规则干预
- 日志跟踪
- 监测指标

`data-agent-service` 当前三模块没有形成这一套通用智能体治理能力。

这部分建议：

- 先不直接迁移 `BasicAgent` 文档里未实现或未完全沉淀的部分
- 但在架构设计中预留能力位

优先级建议：

1. 日志
2. 数据/规则过滤
3. 监测
4. 长期记忆

兼容性要求：

- 这些能力应作为新增通用智能体治理能力接入
- 不应修改现有数据源、向量、知识接口的原始行为来“顺带实现”

## 6. 可以直接复用 data-agent-service 现有实现的内容

这一类能力不建议重写，应优先直接复用。

### 6.1 模型工厂与基础模型配置

可直接复用：

- `DynamicModelFactory`
- `ModelConfigDataServiceImpl`
- `ModelConfigMapper`
- `ModelConfigDTO`

建议方式：

- 作为模型装配的基础实现保留
- 但在上层 Agent 执行器增加按智能体配置调用的方式

补充说明：

- 这属于“旧接口保留，新入口扩展”
- 不应把现有模型工厂改造成只服务通用智能体

### 6.2 `framework` 中的运行时基础设施

可直接复用：

- `CapabilityComponentConfig`
- `EnhancedTokenCountBatchingStrategy`
- `CapabilityComponentProperties`
- `DataAgentProperties`
- AOP / MyBatis / 线程池配置

原因：

- 这些已经是底层运行时能力
- 没必要为通用智能体重复建设

### 6.3 向量存储与检索服务

可直接复用：

- `VectorStoreService`
- `VectorStoreServiceImpl`
- `DynamicFilterService`
- `HybridRetrievalStrategy`
- `FusionStrategy`

原因：

- 通用智能体只是消费这些能力
- 检索、删除、混合检索等已经实现得比较完整

需要做的是加一层 Agent 适配，而不是重写底层检索逻辑。

补充说明：

- 所有 Agent 侧知识增强逻辑，尽量收敛在新增适配层
- 底层 `VectorStoreService` 保持中立

### 6.4 Dify 知识库服务

可直接复用：

- `DifyApiService`
- `DifyApiServiceImpl`

原因：

- 这是一个独立知识源接入服务
- 适合作为当前阶段通用智能体知识能力的唯一实现

### 6.5 数据源管理与连接器

可直接复用：

- `DatasourceService`
- `DatasourceServiceImpl`
- `DatasourceCapabilityHandlerFactory`
- `DatasourceSupport`
- `SqlExecutor`
- 各类数据库连接池/Accessor/Ddl 实现

原因：

- 这是通用智能体做数据查询能力最有价值的底座
- 现有实现已经比较完整

建议只新增：

- Agent tool 适配层
- 安全策略
- 工具 schema 定义

### 6.6 元数据、关系、语义与全景数据能力

可直接复用：

- `DataTable`
- `DataField`
- `DataRelation`
- `DataSemantic`
- Panorama 相关实体与服务

原因：

- 通用智能体若要做数据问答、数据解释、结构化检索，这些元数据能力非常关键
- 不应另起一套

### 6.7 资源管理与支持类

可复用：

- `CapabilityUtil`
- `ResultSetConvertUtil`
- `DatasourceSupport`
- `DocumentSupport`
- `NacosConfigSupport`
- 其他 support / utils

这些能力适合作为智能体执行过程中的下层依赖。

## 7. 配置资源与 SKILL 的建议处理方式

基于当前改造方向，建议不要再把通用智能体的挂载内容区分成“资源类配置”和“非资源类配置”。

更合理的划分应是：

```text
1. 业务资源
2. 配置资源
3. 运行时快照
```

其中：

- 业务资源：数据源、知识库、MCP、组件、SKILL 等
- 配置资源：模型、提示词、提示词变量、记忆、知识增强配置、回复兜底、过滤规则等
- 运行时快照：发布态固化后的完整 JSON 配置

也就是说，只要内容是独立于 agent 本体存储，并通过挂载进入智能体运行的，都应纳入“资源配置体系”。

因此：

- 不建议继续使用“非资源类配置”这个说法
- 建议统一使用“配置资源”

### 7.1 配置资源的建议范围

建议以下内容统一按“配置资源”看待：

- `modelProvider / model / parameter`
- `instructions`
- `promptVariables`
- `memory`
- `knowledge`（指知识增强配置，而不是知识库资源本身）
- `fallback reply`
- `filter rules`

这里需要特别区分两层概念：

- 知识库资源：例如 Dify dataset，本身属于业务资源
- `knowledge` 配置：描述智能体如何启用、选择和使用知识库，属于配置资源

因此，`knowledge` 被归入配置资源时，指的是：

- 知识增强配置

而不是：

- 知识库资源本身

其它这些内容虽然不像数据源、知识库资源那样是业务资源，但如果采用独立存储、独立挂载、可复用、可审计的方式管理，本质上就是智能体的配置资源。

这样带来的好处是：

- 挂载模型统一
- 资源治理口径统一
- 调试态装配方式统一
- 发布态快照生成方式统一
- 后续扩展 SKILL、规则包、模板包时模型一致

### 7.2 业务资源与配置资源的关系

建议后续文档和实现里统一按下面的方式理解：

```text
Agent
  -> 挂载业务资源
  -> 挂载配置资源
  -> 调试态运行时组装
  -> 发布态固化为运行时快照
```

其中：

- 业务资源决定“可以接入哪些外部或平台能力”
- 配置资源决定“智能体如何理解、约束、记忆、知识增强、回复和治理”

### 7.3 SKILL 的建议处理方式

`BasicAgent` 现有实现中，SKILL 还是设计增强项，不一定有完全落地实现。  
在 `data-agent-service` 里实现时，建议不要等待现成实现，而应直接纳入本次改造的一级资源能力。

建议设计为：

```text
skills
  -> 作为 AgentConfig 顶层配置项
  -> 参与 Prompt / 上下文增强
  -> 不直接等价于工具
```

建议能力边界：

- 提供专业规则
- 提供任务处理方法
- 提供固定分析框架
- 提供输出结构规范

不直接承担：

- 外部执行
- HTTP 调用
- 数据库查询

建议在运行时接入位置上，放在：

```text
模板
  -> 模板变量
  -> 记忆
  -> 知识库
  -> skills
  -> 最终共同影响系统提示词和上下文
```

也就是说，SKILL 应归类为：

- 上下文增强能力

而不是：

- tool calling 能力

从资源化建模角度，它更适合归入：

- 业务资源或能力资源

而不是内嵌在 agent 本体中的固定字段。

## 8. 建议的实施顺序

### 第一阶段：先搭通用智能体最小闭环

目标：

- 能创建一个 Agent
- 能保存配置
- 能调试
- 能正式运行

优先实现：

1. 应用实体 + 版本实体
2. `AgentConfig`
3. `AgentRequest` / `AgentResponse`
4. `BasicAgentExecutor`
5. 模型装配适配
6. 短期记忆
7. Prompt 模板变量

阶段约束：

- 第一阶段不改旧接口签名
- 先以新增模块、新服务、新配置对象为主
- 旧能力只作为依赖被调用

### 第二阶段：接入现有能力服务

目标：

- 让 Agent 具备知识、数据、工具能力

优先实现：

1. `knowledge` 直接接入 `DifyApiService`
2. 数据源工具适配
3. MCP 工具适配
4. 组件能力适配
5. skills 上下文增强
6. 长期记忆的向量检索适配

阶段约束：

- 所有能力接入优先采用 adapter / facade 模式
- 尽量避免修改 `common`、`framework`、`capability-component` 的现有服务语义

### 第三阶段：补治理与平台能力

目标：

- 让通用智能体具备可运营、可维护、可观测能力

优先实现：

1. 发布 API / 应用 / 工具
2. 数据干预与规则干预
3. 日志与流程追踪
4. 监测指标
5. 长期记忆

阶段约束：

- 治理能力新增时，不反向污染底层通用服务接口
- 监测和日志优先在智能体执行层采集

## 9. 建议的代码组织方式

建议不要把所有内容都堆到 `capability-component` 里。

建议新建一个面向通用智能体的模块，例如：

```text
basic-agent
```

或：

```text
agent-app
```

模块职责建议：

- 保存应用、版本、配置、请求、响应、执行器
- 调用 `common` 的模型能力
- 调用 `framework` 的运行时装配能力
- 调用 `capability-component` 的知识、数据源、向量、Dify、资源能力

兼容性收益：

- 能最大限度避免改动已有三模块的公开接口
- 能把“新智能体能力”和“旧基础能力”隔离开
- 出问题时影响面更可控

不建议做法：

- 把 `BasicAgentExecutor`、应用版本、配置模型、工具调用编排全部直接塞进 `capability-component`

因为这会把“能力服务层”和“应用运行层”混在一起。

## 10. 最终归类清单

### 10.1 可直接迁移 BasicAgent 的内容

- 应用实体与版本实体
- 版本管理与发布逻辑
- `AgentConfig`
- `AgentRequest` / `AgentResponse` / `AgentContext`
- `BasicAgentExecutor`
- Tool calling 编排体系
- Prompt 模板变量体系
- 记忆执行链
- 流式/非流式执行链

### 10.2 需要改造 data-agent-service 现有能力的内容

- 全局激活模型 -> 智能体可选模型
- Dify 服务 -> 智能体知识配置唯一知识源
- 向量检索服务 -> 工具检索与长期记忆底层能力
- 数据源服务 -> Agent 工具能力
- MCP 服务 -> 支持具体工具级选择
- 资源管理 -> 智能体装载资源体系
- 新增日志、过滤、监测、长期记忆能力

改造原则：

- 优先新增，不优先替换
- 优先包装，不优先侵入
- 优先兼容，不优先重构旧接口

### 10.2.1 资源化建模原则修正

后续实现中建议统一遵循：

```text
只要内容独立于 agent 存储，并通过挂载进入智能体运行，
就应视为资源配置体系的一部分。
```

因此不再建议使用：

- 非资源类配置

而建议统一为：

- 业务资源
- 配置资源

建议归类如下：

业务资源：

- 数据源
- 知识库
- MCP 服务 / MCP 工具
- 组件
- SKILL

配置资源：

- 模型
- 提示词
- 提示词变量
- 记忆
- 知识增强配置（不是知识库资源本体）
- 回复兜底
- 过滤规则

发布态：

- 将业务资源挂载结果 + 配置资源挂载结果
- 统一固化为 JSON 运行时快照

### 10.3 可直接复用 data-agent-service 的内容

- `DynamicModelFactory`
- `ModelConfigDataServiceImpl`
- `CapabilityComponentConfig`
- `EnhancedTokenCountBatchingStrategy`
- `CapabilityComponentProperties`
- `VectorStoreService` 及其检索体系
- `DifyApiService`
- `DatasourceService`
- `SqlExecutor`
- 多数据库连接器
- 元数据/关系/语义/全景类资源能力
- 各类 support / utils

## 11. 结论

`data-agent-service` 已经有足够强的底层能力，不适合重新发明一套“模型、检索、数据源、知识库”基础设施。  
真正需要补的是 `BasicAgent` 那一层“通用智能体应用框架”。

因此正确的改造路径应是：

```text
迁移 BasicAgent 的应用层与执行层
  + 复用 data-agent-service 的底层能力层
  + 在中间增加能力适配层
```

如果只迁移 `BasicAgent` 而不复用 `data-agent-service`，会重复建设底层能力。  
如果只复用 `data-agent-service` 而不补 `BasicAgent` 运行框架，则无法形成真正的通用智能体产品能力。

最终目标应是：

```text
data-agent-service
  -> 提供能力底座

BasicAgent风格的通用智能体模块
  -> 提供应用配置、执行编排、发布与运行能力
```

并且要满足：

```text
旧模块继续按原方式可用
新智能体模块在不破坏旧接口的前提下演进
```

从资源模型上，最终建议收敛为：

```text
调试态
  -> 通过资源绑定挂载业务资源和配置资源

发布态
  -> 将资源绑定结果统一固化为 JSON 快照

运行态
  -> 调试运行与发布运行最终都落到统一 AgentConfig 视图
```
