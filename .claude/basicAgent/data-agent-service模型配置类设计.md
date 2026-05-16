# data-agent-service 模型配置类设计

## 1. 设计目标

为 `BasicAgent` 在 `data-agent-service` 中补齐两层能力：

- provider/model 管理层
- agent 级模型运行时装配层

同时保持现有平台级默认模型链路兼容：

- `AiModelRegistry`
- `DynamicModelFactory`
- `ModelConfigDataService`

---

## 2. 分层设计

建议拆成四层：

### 2.1 管理接口层

对外提供 provider/model 管理 API。

建议类：

- `ProviderController`
- `ModelController`

### 2.2 管理服务层

负责 provider/model 的业务管理。

建议类：

- `ProviderManager`
- `ModelManager`
- `ProviderManagerImpl`
- `ModelManagerImpl`

### 2.3 运行时装配层

负责把 agent 模型配置转换成可执行 `ChatModel` / `ChatClient`。

建议类：

- `AgentModelFacade`
- `AgentChatClientFactory`
- `AgentModelConfigResolver`

### 2.4 底层复用层

复用现有全局模型基础设施。

已有类：

- `AiModelRegistry`
- `DynamicModelFactory`
- `ModelConfigDTO`
- `ModelConfigDataService`

---

## 3. 管理域类设计

## 3.1 `ProviderEntity`

用途：

- 持久化 provider 基本信息和凭证信息

建议字段：

```java
public class ProviderEntity {
    private Long id;
    private String providerCode;
    private String name;
    private String description;
    private String icon;
    private String protocol;
    private Boolean enabled;
    private String source;
    private String apiKey;
    private String endpoint;
    private String extraCredentialJson;
    private LocalDateTime createdTime;
    private LocalDateTime updatedTime;
    private Integer isDeleted;
}
```

说明：

- `providerCode` 作为业务唯一标识
- `protocol` 初期可只支持 `openai`
- `apiKey/endpoint` 可先平铺，复杂凭证放 `extraCredentialJson`

## 3.2 `ModelEntity`

用途：

- 持久化模型元数据

建议字段：

```java
public class ModelEntity {
    private Long id;
    private String providerCode;
    private String modelId;
    private String name;
    private String modelType;
    private String mode;
    private String tags;
    private String icon;
    private Boolean enabled;
    private String defaultParametersJson;
    private String supportedParametersJson;
    private LocalDateTime createdTime;
    private LocalDateTime updatedTime;
    private Integer isDeleted;
}
```

说明：

- `modelId` 是调用模型时的真实模型名，例如 `gpt-4o-mini`
- `name` 是平台展示名称
- `defaultParametersJson` 存平台默认参数
- `supportedParametersJson` 存参数规则定义

## 3.3 `ProviderConfigDTO`

用途：

- controller 和 manager 间传输 provider 数据

建议字段：

```java
public class ProviderConfigDTO {
    private Long id;
    private String providerCode;
    private String name;
    private String description;
    private String icon;
    private String protocol;
    private Boolean enabled;
    private String endpoint;
    private String apiKey;
    private Map<String, Object> credentialConfig;
    private List<String> supportedModelTypes;
}
```

## 3.4 `ModelMetaDTO`

用途：

- controller 和 manager 间传输模型元数据

建议字段：

```java
public class ModelMetaDTO {
    private Long id;
    private String providerCode;
    private String modelId;
    private String name;
    private String modelType;
    private String mode;
    private List<String> tags;
    private String icon;
    private Boolean enabled;
    private Map<String, Object> defaultParameters;
    private List<ModelParameterRuleDTO> supportedParameters;
}
```

## 3.5 `ModelParameterRuleDTO`

用途：

- 统一表达模型参数规则

建议字段：

```java
public class ModelParameterRuleDTO {
    private String key;
    private String label;
    private String valueType;
    private Boolean required;
    private Object defaultValue;
    private Object minValue;
    private Object maxValue;
    private List<Object> options;
    private Boolean enabled;
}
```

---

## 4. 管理服务设计

## 4.1 `ProviderManager`

建议接口：

```java
public interface ProviderManager {
    boolean addProvider(ProviderConfigDTO request);
    boolean updateProvider(ProviderConfigDTO request);
    boolean deleteProvider(String providerCode);
    List<ProviderConfigDTO> queryProviders(String name);
    ProviderConfigDTO getProviderDetail(String providerCode);
}
```

职责：

- provider 基本信息管理
- provider 凭证管理
- provider 启停

## 4.2 `ModelManager`

建议接口：

```java
public interface ModelManager {
    boolean addModel(ModelMetaDTO request);
    boolean updateModel(ModelMetaDTO request);
    boolean deleteModel(String providerCode, String modelId);
    List<ModelMetaDTO> queryModels(String providerCode);
    List<ModelMetaDTO> queryEnabledModels();
    ModelMetaDTO getModelDetail(String providerCode, String modelId);
    ModelMetaDTO findModelByIdOrName(String modelIdOrName);
    List<ModelParameterRuleDTO> getModelParameterRules(String providerCode, String modelId);
}
```

职责：

- 模型元数据管理
- provider 归属关系管理
- 模型查询与选择
- 参数规则查询

## 4.3 `ProviderManagerImpl`

依赖：

- `ProviderMapper`
- 可选 `ModelMapper`

关键逻辑：

- 生成 `providerCode`
- 加密或安全保存 `apiKey`
- 删除 provider 前检查是否还有模型关联

## 4.4 `ModelManagerImpl`

依赖：

- `ModelMapper`
- `ProviderMapper`

关键逻辑：

- 新增模型前校验 provider 存在
- 查询启用模型时只返回 `enabled=true`
- `findModelByIdOrName(...)` 支持：
  - 按 `id`
  - 按 `modelId`
  - 按 `name`

---

## 5. 管理接口设计

## 5.1 `ProviderController`

建议接口：

```java
@RestController
@RequestMapping("/providers")
public class ProviderController {
    @PostMapping
    public Result<Boolean> addProvider(...)

    @PutMapping("/{providerCode}")
    public Result<Boolean> updateProvider(...)

    @DeleteMapping("/{providerCode}")
    public Result<Boolean> deleteProvider(...)

    @GetMapping
    public Result<List<ProviderConfigDTO>> queryProviders(...)

    @GetMapping("/{providerCode}")
    public Result<ProviderConfigDTO> getProviderDetail(...)

    @PostMapping("/{providerCode}/models")
    public Result<Boolean> addModel(...)

    @PutMapping("/{providerCode}/models/{modelId}")
    public Result<Boolean> updateModel(...)

    @DeleteMapping("/{providerCode}/models/{modelId}")
    public Result<Boolean> deleteModel(...)

    @GetMapping("/{providerCode}/models")
    public Result<List<ModelMetaDTO>> queryModels(...)

    @GetMapping("/{providerCode}/models/{modelId}")
    public Result<ModelMetaDTO> getModelDetail(...)

    @GetMapping("/{providerCode}/models/{modelId}/parameter-rules")
    public Result<List<ModelParameterRuleDTO>> getModelParameterRules(...)
}
```

## 5.2 `ModelController`

建议接口：

```java
@RestController
@RequestMapping("/models")
public class ModelController {
    @GetMapping("/{modelType}/selector")
    public Result<List<ModelProviderGroupDTO>> getModelSelector(...)

    @GetMapping("/enabled")
    public Result<List<ModelMetaDTO>> getEnabledModels()

    @GetMapping("/supported")
    public Result<List<String>> getSupportedProviders()
}
```

补充 DTO：

```java
public class ModelProviderGroupDTO {
    private ProviderConfigDTO provider;
    private List<ModelMetaDTO> models;
}
```

---

## 6. 运行时装配类设计

## 6.1 `AgentModelConfig`

用途：

- 挂在 `BasicAgent` 配置中
- 表达 agent 自己的模型选择和运行参数

建议字段：

```java
public class AgentModelConfig {
    private Long modelConfigId;
    private String provider;
    private String modelName;
    private String baseUrl;
    private String apiKey;
    private String completionsPath;
    private Double temperature;
    private Integer maxTokens;
    private Double topP;
    private Double repetitionPenalty;
    private Boolean thinking;
}
```

说明：

- `modelConfigId` 优先表示“引用平台模型”
- 其余字段表示“运行时覆写项”
- 如果 `modelConfigId` 为空，则可走完全自定义配置

## 6.2 `AgentModelConfigResolver`

职责：

- 将 `AgentModelConfig` 解析成最终 `ModelConfigDTO`
- 处理“平台模型 + agent 覆写”
- 处理“纯 agent 自定义模型”

建议接口：

```java
public interface AgentModelConfigResolver {
    ModelConfigDTO resolve(AgentModelConfig agentConfig);
}
```

建议实现逻辑：

1. 若 `modelConfigId` 不为空：
   - 从 `ModelManager` 查询模型
   - 从 `ProviderManager` 查询 provider 凭证
   - 组装基础 `ModelConfigDTO`
   - 用 agent 参数覆写
2. 若 `modelConfigId` 为空但 `baseUrl/apiKey/modelName` 完整：
   - 直接构造 `ModelConfigDTO`
3. 若 agent 配置缺失：
   - 返回 `null`，由 facade 决定是否回退平台默认模型

## 6.3 `AgentChatClientFactory`

职责：

- 为单个 agent 配置创建专属 `ChatClient`
- 不做全局缓存

建议接口：

```java
public interface AgentChatClientFactory {
    ChatModel createChatModel(ModelConfigDTO config);
    ChatClient createChatClient(ModelConfigDTO config, boolean enableMcp);
}
```

建议实现：

- 内部复用 `DynamicModelFactory`
- 当 `enableMcp=true` 时挂载 `ToolCallbackProvider`

## 6.4 `AgentModelFacade`

职责：

- 作为 `BasicAgent` 模型入口
- 统一封装“agent 优先，平台回退”

建议接口：

```java
public interface AgentModelFacade {
    ChatClient getChatClient(AgentModelConfig config, boolean enableMcp);
    ChatModel getChatModel(AgentModelConfig config);
    ModelConfigDTO resolveModelConfig(AgentModelConfig config);
}
```

建议实现逻辑：

1. 调用 `AgentModelConfigResolver.resolve(...)`
2. 如果拿到结果：
   - 交给 `AgentChatClientFactory`
3. 如果没拿到结果：
   - 回退到 `AiModelRegistry.getChatClient(enableMcp)`

---

## 7. 底层复用类修改建议

## 7.1 `ModelConfigDTO`

建议新增字段：

```java
private Double topP;
private Double repetitionPenalty;
private Boolean thinking;
```

可选新增：

```java
private Map<String, Object> extraParams;
```

## 7.2 `DynamicModelFactory`

`createChatModel(ModelConfigDTO modelConfig)` 建议扩成：

```java
OpenAiChatOptions.builder()
    .model(modelConfig.getModelName())
    .temperature(modelConfig.getTemperature())
    .maxTokens(modelConfig.getMaxTokens())
    .topP(modelConfig.getTopP())
    .presencePenalty(...)
    .frequencyPenalty(...)
```

当前阶段至少支持：

- `temperature`
- `maxTokens`
- `topP`
- `repetitionPenalty`
- `thinking`

`thinking` 建议通过：

- `extraBody`
- 或 provider-compatible 扩展字段

动态生成，不再写死 `false`

## 7.3 `ModelConfigDataService`

保留现有接口：

```java
ModelConfigDTO getActiveConfigByType(ModelType modelType);
```

不直接改造成 agent 专属接口。

---

## 8. Mapper 设计建议

## 8.1 `ProviderMapper`

建议接口：

```java
public interface ProviderMapper {
    int insert(ProviderEntity entity);
    int updateByProviderCode(ProviderEntity entity);
    int softDeleteByProviderCode(String providerCode);
    ProviderEntity selectByProviderCode(String providerCode);
    List<ProviderEntity> selectList(String name);
}
```

## 8.2 `ModelMapper`

建议接口：

```java
public interface ModelMapper {
    int insert(ModelEntity entity);
    int updateByProviderAndModelId(ModelEntity entity);
    int softDeleteByProviderAndModelId(String providerCode, String modelId);
    ModelEntity selectByProviderAndModelId(String providerCode, String modelId);
    List<ModelEntity> selectByProvider(String providerCode);
    List<ModelEntity> selectEnabledList();
    ModelEntity selectByIdOrName(String modelIdOrName);
}
```

---

## 9. BasicAgent 接入点

未来 `BasicAgent` 运行时建议只依赖：

- `AgentModelFacade`

不直接依赖：

- `AiModelRegistry`
- `DynamicModelFactory`
- `ModelConfigMapper`

这样可以保证：

- agent 执行层只关心“我要一个模型客户端”
- 模型选择、回退、参数覆写都封装在 facade 内

---

## 10. 推荐实现顺序

1. 新增管理域 DTO / Entity
2. 新增 `ProviderMapper` / `ModelMapper`
3. 新增 `ProviderManager` / `ModelManager`
4. 新增 `ProviderController` / `ModelController`
5. 扩展 `ModelConfigDTO`
6. 扩展 `DynamicModelFactory`
7. 新增 `AgentModelConfig`
8. 新增 `AgentModelConfigResolver`
9. 新增 `AgentChatClientFactory`
10. 新增 `AgentModelFacade`
11. 在 `BasicAgent` 执行器中接入 `AgentModelFacade`

---

## 11. 最终职责边界

### 平台管理层负责

- provider 管理
- model 管理
- 模型参数规则
- 默认模型配置

### agent 运行时负责

- 选择 agent 模型
- 合并 agent 覆写参数
- 创建本次调用的 `ChatClient`
- 回退平台默认模型

### 现有全局模型层负责

- 非 `BasicAgent` 场景的旧调用路径
- 平台默认模型兜底

---

## 12. 总结

这套设计里，`admin` 的思路被拆成了两部分迁移：

- 管理层：`ProviderManager / ModelManager / Controller`
- 运行层：`AgentModelFacade / AgentChatClientFactory`

而 `data-agent-service` 自己已有的：

- `AiModelRegistry`
- `DynamicModelFactory`
- `ModelConfigDTO`

继续作为底座复用，不推翻重来。
