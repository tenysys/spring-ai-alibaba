# BasicAgent功能配置说明

## 1. 说明

本文档从“功能配置”的角度说明 `BasicAgent`。

重点回答：

1. `BasicAgent` 有哪些核心配置项
2. 每个配置项的功能含义是什么
3. 配置后会影响什么行为
4. 不同配置项适合什么场景

本文档不展开代码实现，只关注：

- 配置项
- 配置语义
- 生效方式
- 使用建议

## 2. 总体理解

`BasicAgent` 的配置可以分成四类：

```text
模型类配置
  -> 决定“由谁回答”

提示词与上下文类配置
  -> 决定“回答时遵循什么规则、看到什么上下文”

外部能力类配置
  -> 决定“需要时可以调用什么能力”

交互体验类配置
  -> 决定“用户如何与这个 agent 交互”
```

对应到主要配置项，大致是：

- 模型类：`modelProvider`、`model`、`parameter`
- 提示词与上下文类：`instructions`、`promptVariables`、`memory`、`fileSearch`
- 外部能力类：`tools`、`mcpServers`、`agentComponents`、`workflowComponents`
- 交互体验类：`prologue`

## 3. 顶层配置项总览

`BasicAgent` 的核心配置项包括：

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

下面按配置项逐一说明。

## 4. 模型类配置

### 4.1 `modelProvider`

功能含义：

- 指定模型服务提供方
- 决定连接到哪个模型平台或账号配置

它主要影响：

- 使用哪套凭证
- 请求发往哪个模型服务地址
- 本次调用可使用哪类模型资源

适用场景：

- 同一系统里配置多个模型服务来源
- 不同环境、不同租户使用不同 provider

使用建议：

- 当你要切换“模型服务来源”时，优先改这个字段
- 它不是模型名，而是模型连接配置

### 4.2 `model`

功能含义：

- 指定本次调用使用的具体模型名称

它主要影响：

- 模型能力
- 响应质量
- 成本与速度
- 上下文长度

适用场景：

- 同一 provider 下切换不同模型
- 在效果、成本、时延之间做平衡

使用建议：

- 当你要切换“具体模型”时改这个字段
- 不要把它和 `modelProvider` 混淆

### 4.3 `modalityType`

功能含义：

- 描述模型支持的模态类型

它主要影响：

- 是否适合纯文本对话
- 是否适合图片等多模态输入

适用场景：

- 区分文本模型和多模态模型

使用建议：

- 如果 agent 需要处理图片、文件等输入，应确认该字段与模型能力匹配

### 4.4 `parameter`

功能含义：

- 配置模型生成参数

典型子项包括：

- `maxTokens`
- `temperature`
- `topP`
- `repetitionPenalty`

它主要影响：

- 输出长度
- 输出随机性
- 输出稳定性
- 重复表达控制

使用建议：

- 更稳定、更可控的业务回答可适当降低随机性
- 创意型输出场景可适当提高随机性
- 长文场景要关注 `maxTokens`

## 5. 提示词与上下文类配置

### 5.1 `instructions`

功能含义：

- 定义 agent 的系统提示词
- 规定 agent 的角色、规则、目标和输出要求

它主要影响：

- agent 如何理解自己的职责
- 回答风格与约束
- 工具使用倾向
- 与知识库和模板变量的协同方式

适用场景：

- 定义客服助手、研究助手、业务顾问等不同角色
- 规定输出格式、语言风格、行为边界

使用建议：

- 把它当作 agent 的行为说明书
- 应尽量清晰、稳定、可复用

### 5.2 `promptVariables`

功能含义：

- 定义提示词模板变量
- 让 `instructions` 支持参数化

每个变量通常包含：

- 变量名
- 类型
- 描述
- 默认值

它主要影响：

- 同一份提示词模板能否在不同场景复用
- 是否支持按请求动态注入上下文

适用场景：

- 按租户、角色、部门、业务线注入不同上下文
- 动态控制提示词中的业务参数

使用建议：

- 适合放相对稳定、结构清晰的上下文变量
- 不适合替代长篇业务说明文档

### 5.3 `memory`

功能含义：

- 开启或配置会话记忆
- 让 agent 能在后续请求中延续上下文

核心子项：

- `dialogRound`

它主要影响：

- 多轮对话连续性
- 用户是否需要重复前文

适用场景：

- 客服对话
- 连续问答
- 分步骤任务协作

使用建议：

- 如果 agent 主要做单轮问答，可以不依赖记忆
- 如果 agent 需要持续对话，应结合 `conversationId` 使用

### 5.4 `fileSearch`

功能含义：

- 配置知识库检索能力
- 让 agent 在回答时基于指定资料进行补充

常见子项包括：

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

它主要影响：

- 是否启用知识库
- 从哪些知识库检索
- 检索结果多少、精度如何
- 是否展示引用信息

适用场景：

- 企业知识问答
- 产品文档问答
- 政策、制度、规范解读

使用建议：

- 如果不需要文档支撑，关闭即可
- 如果需要可引用、可追溯回答，建议配合 citation 使用

## 6. 外部能力类配置

### 6.1 `tools`

功能含义：

- 给 agent 挂载插件工具
- 让 agent 可以调用外部 HTTP/OpenAPI 能力

它主要影响：

- agent 是否能访问外部业务系统
- agent 是否能执行标准 API 操作

适用场景：

- 查询第三方数据
- 调用企业业务系统接口
- 执行外部操作

使用建议：

- 当你希望 agent 能“做事”，而不只是“回答”时使用

### 6.2 `mcpServers`

功能含义：

- 给 agent 挂载 MCP 服务能力
- 让 agent 可以通过 MCP 协议调用外部工具

它主要影响：

- agent 能否使用标准工具协议下的外部能力

适用场景：

- 对接 MCP 工具生态
- 使用外部工具服务自带的 tool 定义

使用建议：

- 当外部能力本身已经以 MCP 服务形式提供时优先使用

### 6.3 `agentComponents`

功能含义：

- 挂载其他已发布 agent 组件
- 让当前 agent 可以复用其他 agent 的能力

它主要影响：

- agent 能否像调用工具一样调用内部智能体能力

适用场景：

- 多 agent 协作
- 专家 agent 能力复用
- 领域能力模块化

使用建议：

- 适合把成熟 agent 封装为可复用能力，而不是重复创建

### 6.4 `workflowComponents`

功能含义：

- 挂载已发布 workflow 组件
- 让当前 agent 可以触发内部工作流能力

它主要影响：

- agent 是否能调用结构化业务流程

适用场景：

- 表单处理
- 审批、编排、流程驱动场景
- 需要稳定步骤执行的任务

使用建议：

- 当任务是明确流程型而非纯对话型时，workflow 组件通常更合适

## 7. 交互体验类配置

### 7.1 `prologue`

功能含义：

- 配置前端欢迎语与建议问题

常见子项：

- `prologueText`
- `suggestedQuestions`

它主要影响：

- 用户第一次进入时看到什么提示
- 用户是否能快速知道 agent 能做什么

适用场景：

- 面向终端用户的交互式 agent
- 需要降低上手门槛的场景

使用建议：

- 欢迎语应简洁说明能力边界
- 建议问题应贴近真实使用场景

## 8. 配置项之间的协同关系

### 8.1 模型与提示词

协同关系：

- `modelProvider` + `model` 决定由谁回答
- `instructions` 决定如何回答
- `parameter` 决定回答风格和输出控制

可以理解为：

```text
模型
  -> 决定能力底座

提示词
  -> 决定行为策略

参数
  -> 决定表达风格
```

### 8.2 模板变量与知识库

协同关系：

- `promptVariables` 为提示词提供动态参数
- `fileSearch` 为提示词提供文档上下文

因此它们共同影响：

- 模型最终看到的系统上下文

### 8.3 记忆与消息

协同关系：

- `memory` 负责跨请求延续上下文
- `messages` 负责本次请求显式提供上下文

使用时应明确：

- 是主要依赖前端传历史
- 还是主要依赖后端记忆

### 8.4 插件、MCP 与组件

协同关系：

- 三者都属于可调用能力
- 但来源不同

区别在于：

- `tools`：外部 API 能力
- `mcpServers`：外部 MCP 工具能力
- `agentComponents` / `workflowComponents`：平台内部复用能力

## 9. 常见配置组合

### 9.1 纯问答型 agent

典型配置：

- `modelProvider`
- `model`
- `instructions`
- `parameter`

特点：

- 结构简单
- 适合通用问答
- 不依赖外部资源

### 9.2 带知识库问答型 agent

典型配置：

- `modelProvider`
- `model`
- `instructions`
- `fileSearch`

特点：

- 回答更依赖企业资料
- 适合文档问答、制度问答、产品问答

### 9.3 连续会话型 agent

典型配置：

- `modelProvider`
- `model`
- `instructions`
- `memory`

特点：

- 强调多轮连续上下文
- 适合客服、陪伴、长期任务协作

### 9.4 执行型 agent

典型配置：

- `modelProvider`
- `model`
- `instructions`
- `tools` 或 `mcpServers`

特点：

- 不只回答，还能执行外部操作

### 9.5 组合型 agent

典型配置：

- `modelProvider`
- `model`
- `instructions`
- `promptVariables`
- `memory`
- `fileSearch`
- `tools` / `mcpServers`
- `agentComponents` / `workflowComponents`

特点：

- 复合能力最强
- 适合复杂业务智能体

## 10. 配置使用建议

### 10.1 优先明确 agent 类型

在配置前，建议先明确 agent 更偏向哪一类：

- 问答型
- 检索型
- 执行型
- 流程型
- 组合型

这样更容易判断哪些配置应该启用。

### 10.2 不要一次开启所有能力

虽然 `BasicAgent` 可以装很多能力，但不代表每个 agent 都要全部开启。

建议原则：

- 先满足核心目标
- 再逐步增加上下文能力或执行能力

### 10.3 先设计提示词，再补资源能力

多数场景中，建议先明确：

- `instructions`
- `promptVariables`
- 模型和参数

在此基础上再考虑：

- 是否需要知识库
- 是否需要记忆
- 是否需要插件/MCP/组件

### 10.4 注意上下文重复

如果同时使用：

- 前端历史消息
- 后端记忆
- 知识库注入
- 大量模板变量

则可能造成上下文膨胀。

因此建议控制：

- 提示词长度
- 会话历史规模
- 检索结果规模

## 11. 当前结论

从配置视角看，`BasicAgent` 的功能配置可以总结为：

```text
modelProvider / model / parameter
  -> 决定模型底座

instructions / promptVariables
  -> 决定行为规则与动态提示词

memory / fileSearch
  -> 决定上下文增强方式

tools / mcpServers / agentComponents / workflowComponents
  -> 决定可调用能力范围

prologue
  -> 决定前端交互入口体验
```

因此配置 `BasicAgent` 的本质，就是在回答三个问题：

1. 用哪个模型来思考与生成
2. 用什么上下文来约束和增强回答
3. 需要时能调用哪些能力来完成任务

这三点共同决定了一个 `BasicAgent` 的最终行为。
