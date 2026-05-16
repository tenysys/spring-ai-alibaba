# data-agent-service 模型配置实现清单

## 1. 目标

根据 `通用智能体设计方案.md` 的 `3.5 模型能力`，在 `data-agent-service` 中补齐 `BasicAgent` 所需模型配置能力。

目标要求：

- 每个智能体可独立配置模型
- 支持按智能体配置创建 `ChatModel` / `ChatClient`
- 保留平台默认模型回退能力
- 不改变现有平台级激活模型的旧调用路径

支持参数：

- `maxTokens`
- `temperature`
- `topP`
- `repetitionPenalty`
- `thinking`

---

## 2. 当前现状

当前 `data-agent-service` 已有平台级模型配置底座，核心代码位于：

- `common/.../aimodelconfig/AiModelRegistry.java`
- `common/.../aimodelconfig/DynamicModelFactory.java`
- `common/.../aimodelconfig/ModelConfigDataService.java`
- `common/.../aimodelconfig/ModelConfigDataServiceImpl.java`
- `common/.../model/ModelConfigDTO.java`

现状特点：

- `AiModelRegistry` 负责全局单例 `ChatClient` / `EmbeddingModel`
- `ModelConfigDataService` 只支持按 `ModelType` 读取平台当前激活模型
- `DynamicModelFactory` 能基于 `ModelConfigDTO` 创建模型
- 当前 `ChatModel` 创建逻辑本质上是 OpenAI-compatible
- 当前仅使用了 `modelName`、`temperature`、`maxTokens`
- `thinking` 目前被硬编码关闭

---

## 3. 现有可复用内容

### 3.1 `AiModelRegistry`

用途：

- 继续保留为平台默认模型入口
- 继续服务旧业务调用链
- 作为 `BasicAgent` 无独立模型配置时的回退来源

结论：

- 保留，不改调用语义

### 3.2 `DynamicModelFactory`

用途：

- 继续作为底层 `ChatModel` / `EmbeddingModel` 构造器

结论：

- 扩展，不重写

### 3.3 `ModelConfigDTO`

用途：

- 继续作为统一模型配置 DTO

结论：

- 扩字段，不新造一套重复 DTO

### 3.4 `ModelConfigDataService`

用途：

- 继续用于读取平台激活模型

结论：

- 保留现有接口
- 不把 agent 专属逻辑直接塞进现有“激活模型读取”接口

### 3.5 `ProviderManager / ModelManager` 设计思路

`admin` 模块里真正支撑模型平台化管理的，不只是 controller，而是：

- `ProviderManager`
- `ModelManager`

这两个 manager 的职责可以概括为：

- `ProviderManager`
  - 管理 provider 元数据
  - 管理 provider 凭证
  - 查询 provider 详情
  - 控制 provider 启停
- `ModelManager`
  - 管理模型元数据
  - 归属到某个 provider
  - 查询 provider 下模型
  - 查询启用模型
  - 查询模型参数规则

如果当前目标是让 `data-agent-service` 同时具备：

- `BasicAgent` 运行时模型能力
- 平台化模型/provider 管理能力

那么这两层也应纳入实现范围，而不应只保留“读取激活模型”。

---

## 4. 当前缺口

### 4.1 配置粒度不对

当前只有“平台级激活模型”。

`BasicAgent` 需要：

- agent 自身带模型配置
- 调用时优先使用 agent 配置
- 未配置时回退平台激活模型

### 4.2 参数不完整

当前缺少：

- `topP`
- `repetitionPenalty`
- `thinking`

### 4.3 运行链路未分层

当前只有：

- 平台默认模型链路

缺少：

- agent 专属模型链路

### 4.4 缺少 provider/model 管理域

当前 `data-agent-service` 只有：

- `model_config` 表读取
- `ModelConfigMapper.selectActiveByType(...)`

缺少完整管理能力：

- provider 增删改查
- provider 凭证管理
- model 增删改查
- provider 和 model 的关联关系
- 模型参数规则查询
- 按 provider 分组的模型选择能力

如果要对齐 `admin` 的能力，这部分必须补齐。

---

## 5. 建议新增类

### 5.0 管理层新增

#### `ProviderManager`

职责：

- provider 生命周期管理
- provider 凭证管理
- provider 启停管理
- provider 查询与详情查询

建议接口：

- `boolean addProvider(ProviderConfigDTO request)`
- `boolean updateProvider(ProviderConfigDTO request)`
- `boolean deleteProvider(String providerCode)`
- `List<ProviderConfigDTO> queryProviders(String name)`
- `ProviderConfigDTO getProviderDetail(String providerCode)`

#### `ModelManager`

职责：

- 模型生命周期管理
- provider 下模型管理
- 启用模型查询
- 按 provider 查询模型
- 按类型查询启用模型
- 查询模型参数规则

建议接口：

- `boolean addModel(ModelMetaDTO request)`
- `boolean updateModel(ModelMetaDTO request)`
- `boolean deleteModel(String providerCode, String modelId)`
- `List<ModelMetaDTO> queryModels(String providerCode)`
- `List<ModelMetaDTO> queryEnabledModels()`
- `ModelMetaDTO getModelDetail(String providerCode, String modelId)`
- `ModelMetaDTO findModelByIdOrName(String modelIdOrName)`
- `List<ModelParameterRuleDTO> getModelParameterRules(String providerCode, String modelId)`

#### `ProviderController`

职责：

- 暴露 provider 管理 REST API
- 提供 provider/model 的平台管理入口

建议接口：

- `POST /providers`
- `PUT /providers/{provider}`
- `DELETE /providers/{provider}`
- `GET /providers`
- `GET /providers/{provider}`
- `POST /providers/{provider}/models`
- `PUT /providers/{provider}/models/{modelId}`
- `DELETE /providers/{provider}/models/{modelId}`
- `GET /providers/{provider}/models`
- `GET /providers/{provider}/models/{modelId}`
- `GET /providers/{provider}/models/{modelId}/parameter-rules`

#### `ModelController`

职责：

- 面向前端提供模型选择和启用模型查询接口

建议接口：

- `GET /models/{modelType}/selector`
- `GET /models/enabled`
- `GET /model/supported`

### 5.1 `AgentModelFacade`

职责：

- 作为 `BasicAgent` 模型能力统一入口
- 对外暴露“按 agent 配置获取 `ChatModel` / `ChatClient`”能力
- 负责 agent 配置优先、平台默认回退

建议接口：

- `ChatClient getChatClient(AgentModelConfig config, boolean enableMcp)`
- `ChatModel getChatModel(AgentModelConfig config)`
- `ModelConfigDTO resolveModelConfig(AgentModelConfig config)`

### 5.2 `AgentChatClientFactory`

职责：

- 根据 agent 的模型配置创建专属 `ChatClient`
- 负责组装 tool callbacks
- 不缓存全局单例，避免不同 agent 间配置串用

建议接口：

- `ChatClient createChatClient(ModelConfigDTO config, boolean enableMcp)`
- `ChatModel createChatModel(ModelConfigDTO config)`

### 5.3 `AgentModelConfig`

职责：

- 承载 `BasicAgent` 自己的模型配置

建议字段：

- `Integer modelConfigId`
- `String provider`
- `String modelName`
- `Double temperature`
- `Integer maxTokens`
- `Double topP`
- `Double repetitionPenalty`
- `Boolean thinking`
- `String baseUrl`
- `String apiKey`
- `String completionsPath`

说明：

- 若后续 `BasicAgent` 只引用平台模型，也可只保存 `modelConfigId + overrides`
- 若要支持完全脱离平台模型，则需允许完整配置直传

### 5.4 管理域 DTO / Entity

建议新增：

- `ProviderConfigDTO`
- `ModelMetaDTO`
- `ModelParameterRuleDTO`
- `ProviderEntity`
- `ModelEntity`
- `ModelCredentialDTO`

说明：

- 不建议直接复用 `ModelConfigDTO` 承载“平台管理视图”和“agent 运行时视图”两种语义
- `ModelConfigDTO` 更适合保留为运行时装配 DTO
- 管理域应有独立 DTO，避免后续字段耦合失控

---

## 6. 需要修改的现有类

### 6.1 `ModelConfigDTO`

新增字段：

- `Double topP`
- `Double repetitionPenalty`
- `Boolean thinking`

可选新增字段：

- `Map<String, Object> extraParams`

### 6.2 `ModelConfig`

如果平台模型表也要承载这些能力，则同步新增字段：

- `topP`
- `repetitionPenalty`
- `thinking`

若当前阶段要同时实现平台管理层，则建议同步梳理表结构，不再只停留在“激活模型配置”一张表。

建议拆分或扩展为：

- `provider` 表
- `model` 表
- 保留或兼容已有 `model_config` 表

至少需要承载：

- provider 基本信息
- provider 凭证
- model 基本信息
- model 类型
- model 状态
- provider-model 关联
- 默认参数
- 支持参数规则

### 6.3 `ModelConfigDataServiceImpl`

若平台库表增加了新字段，需要同步映射到 `ModelConfigDTO`。

### 6.4 `DynamicModelFactory`

`createChatModel(ModelConfigDTO modelConfig)` 需要补齐以下映射：

- `topP`
- `repetitionPenalty`
- `thinking`

改造点：

- 去掉 `thinking` 硬编码关闭
- 使用配置动态生成 `OpenAiChatOptions`
- 保持 OpenAI-compatible 路径不变

### 6.5 `ModelConfigMapper` / 数据访问层

当前只有：

- `selectActiveByType(modelType)`

需要补充：

- provider 查询
- provider 详情查询
- provider 新增/更新/删除
- model 查询
- model 详情查询
- model 新增/更新/删除
- 按 provider 查询模型
- 按类型查询启用模型

说明：

- 如果引入 `ProviderManager / ModelManager`，就必须同步补齐 mapper / repository 层

---

## 7. 保持兼容的原则

必须满足：

- 现有依赖 `AiModelRegistry.getChatClient(...)` 的逻辑不受影响
- 现有 embedding 链路不受影响
- 现有平台级模型配置管理逻辑不受影响

新链路只新增，不替换旧链路：

- 旧链路：平台默认模型
- 新链路：`BasicAgent` 专属模型

管理链路新增，但旧表旧读法可暂兼容：

- 旧管理链路：`model_config` 直接读取激活模型
- 新管理链路：`ProviderManager / ModelManager`

---

## 8. 推荐调用链

### 8.1 旧调用链

业务代码

-> `AiModelRegistry.getChatClient(enableMcp)`

-> `ModelConfigDataService.getActiveConfigByType(CHAT)`

-> `DynamicModelFactory.createChatModel(...)`

-> `ChatClient`

### 8.2 BasicAgent 新调用链

`BasicAgentExecutor`

-> `AgentModelFacade.getChatClient(agentModelConfig, enableMcp)`

-> 如果 agent 配置存在：

-> `AgentChatClientFactory.createChatClient(...)`

-> `DynamicModelFactory.createChatModel(...)`

-> 返回 agent 专属 `ChatClient`

-> 如果 agent 配置不存在：

-> 回退 `AiModelRegistry.getChatClient(enableMcp)`

### 8.3 新增管理链路

前端模型管理页面

-> `ProviderController` / `ModelController`

-> `ProviderManager` / `ModelManager`

-> mapper / repository

-> provider/model 存储

### 8.4 运行时与管理层关系

平台管理层维护：

- provider
- model
- 参数规则
- 默认参数

运行时层消费：

- `AgentModelFacade`
- `AgentChatClientFactory`
- `DynamicModelFactory`
- `AiModelRegistry`

---

## 9. 建议实施顺序

### 第一阶段：管理域底座

1. 设计 provider / model 管理实体与表结构
2. 新增 `ProviderManager`
3. 新增 `ModelManager`
4. 新增 provider/model mapper 或 repository
5. 新增 `ProviderController`
6. 新增 `ModelController`
7. 完成 provider/model 基础 CRUD

### 第二阶段：最小可用运行时改造

1. 新增 `AgentModelFacade`
2. 新增 `AgentChatClientFactory`
3. 扩展 `ModelConfigDTO` 参数字段
4. 扩展 `DynamicModelFactory#createChatModel(...)`
5. 在 `BasicAgent` 执行链中接入 `AgentModelFacade`
6. 保留 `AiModelRegistry` 原逻辑不动

### 第三阶段：平台模型配置增强

1. 若需要平台也支持 `topP / repetitionPenalty / thinking`
2. 扩展 `ModelConfig`、DB 表、Mapper、DTO 映射
3. 让平台激活模型链路也能使用这些参数

### 第四阶段：能力统一

1. 抽象 provider 适配层
2. 若未来接 DashScope / DeepSeek 专属参数
3. 再将 `DynamicModelFactory` 拆为更细粒度 provider factory

---

## 10. 本阶段建议边界

本阶段建议至少做这些事：

- 实现 provider/model 管理域
- 支持 `BasicAgent` 独立模型配置
- 支持参数透传到 `ChatModel`
- 支持平台默认模型回退
- 不改现有全局模型调用路径

本阶段不建议做这些事：

- 不重构 `AiModelRegistry` 为多租户/多 agent 缓存
- 不立即过度设计多 provider 工厂体系
- 不把 embedding / rerank 一起扩大改造范围

---

## 11. 直接落地任务清单

### 必做

- 新增 `ProviderManager`
- 新增 `ModelManager`
- 新增 `ProviderController`
- 新增 `ModelController`
- 设计 provider/model 管理实体或 DTO
- 补齐 provider/model 数据访问层
- 新增 `AgentModelFacade`
- 新增 `AgentChatClientFactory`
- 为 `ModelConfigDTO` 增加 `topP`
- 为 `ModelConfigDTO` 增加 `repetitionPenalty`
- 为 `ModelConfigDTO` 增加 `thinking`
- 修改 `DynamicModelFactory#createChatModel(...)` 支持新参数
- 在 `BasicAgent` 运行入口中接入 agent 专属模型解析逻辑
- 实现“无 agent 配置时回退 `AiModelRegistry`”

### 条件必做

- 如果平台模型表也要承载完整管理能力，则同步修改：
- `ProviderEntity` / `ModelEntity` 或对应表
- `ModelConfig`
- `ModelConfigMapper`
- `ModelConfigDataServiceImpl`
- 相关表结构

### 可后置

- provider 专属 factory 拆分
- agent 级模型缓存策略
- rerank 模型统一接入

---

## 12. 总结

`data-agent-service` 当前并不缺模型底座，缺两层能力：

- provider/model 管理层
- agent 级模型配置装配层

正确做法不是重写现有模型模块，而是：

- 新增 `ProviderManager`
- 新增 `ModelManager`
- 新增 `ProviderController`
- 新增 `ModelController`
- 复用 `DynamicModelFactory`
- 复用 `AiModelRegistry`
- 扩展 `ModelConfigDTO`
- 新增 `AgentModelFacade`
- 新增 `AgentChatClientFactory`

这样可以最小代价满足 `BasicAgent` 的模型能力要求，同时保持现有平台模型调用链稳定。
