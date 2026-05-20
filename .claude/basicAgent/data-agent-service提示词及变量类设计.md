# data-agent-service 提示词及变量类设计

## 1. 目标

基于 [data-agent-service提示词及变量实现请单.md](/I:/java/workplace/spring-ai-alibaba/.claude/basicAgent/data-agent-service提示词及变量实现请单.md)，进一步给出：

- 推荐包结构
- 推荐类清单
- 建议字段
- 建议方法签名
- 各类职责边界
- 最小实现顺序

本文面向 `I:\java\workplace\data-agent-service\basic-agent` 直接落地。

## 2. 推荐包结构

建议在 `basic-agent` 模块中新增如下包：

```text
com.nrec.service.basicagent
  ├─ model
  │  ├─ config
  │  │  └─ AgentConfig.java
  │  ├─ request
  │  │  └─ AgentRequest.java
  │  ├─ response
  │  │  └─ AgentResponse.java
  │  ├─ runtime
  │  │  └─ AgentContext.java
  │  └─ chat
  │     ├─ ChatMessage.java
  │     ├─ MessageRole.java
  │     └─ ContentType.java
  ├─ service
  │  ├─ config
  │  │  ├─ AgentConfigCodec.java
  │  │  └─ impl
  │  │     └─ AgentConfigCodecImpl.java
  │  ├─ prompt
  │  │  ├─ PromptVariableResolver.java
  │  │  ├─ PromptTemplateService.java
  │  │  └─ impl
  │  │     ├─ PromptVariableResolverImpl.java
  │  │     └─ PromptTemplateServiceImpl.java
  │  └─ knowledge
  │     ├─ KnowledgePromptAugmentor.java
  │     └─ impl
  │        └─ KnowledgePromptAugmentorImpl.java
  └─ executor
     └─ BasicAgentExecutor.java
```

## 3. 配置模型

### 3.1 AgentConfig

文件建议：

- `com.nrec.service.basicagent.model.config.AgentConfig`

建议字段：

```java
@Data
public class AgentConfig implements Serializable {

    private String modelProvider;

    private String model;

    private String modalityType;

    private String instructions;

    private Parameter parameter;

    private Memory memory;

    private List<PromptVariable> promptVariables;

    private KnowledgeConfig knowledgeConfig;

    private List<String> mcpServers;

    private List<String> agentComponents;

    private List<String> workflowComponents;

    private List<String> skills;

    private String fallbackReply;

    private Prologue prologue;

    @Data
    public static class Parameter implements Serializable {
        private Integer maxTokens;
        private Double temperature;
        private Double topP;
        private Double repetitionPenalty;
        private Boolean thinking;
    }

    @Data
    public static class Memory implements Serializable {
        private Integer dialogRound;
    }

    @Data
    public static class PromptVariable implements Serializable {
        private String name;
        private String type;
        private String description;
        private String defaultValue;
    }

    @Data
    public static class KnowledgeConfig implements Serializable {
        private Boolean enabled;
        private List<String> datasetIds;
        private Integer topK;
        private Double threshold;
        private Boolean enableCitation;
        private Boolean enableRerank;
    }

    @Data
    public static class Prologue implements Serializable {
        private String prologueText;
        private List<String> suggestedQuestions;
    }
}
```

说明：

- 一期只要 `instructions`、`promptVariables`、`knowledgeConfig` 必须可用
- 其余字段先为后续执行链预留

## 4. 运行协议

### 4.1 AgentRequest

文件建议：

- `com.nrec.service.basicagent.model.request.AgentRequest`

建议字段：

```java
@Data
public class AgentRequest implements Serializable {

    private String agentId;

    private String conversationId;

    private List<ChatMessage> messages;

    private Boolean stream = false;

    private Map<String, String> promptVariables;

    private Map<String, Object> extraParams;
}
```

说明：

- `promptVariables` 对齐 admin 的运行时覆盖能力
- 类型保持 `Map<String, String>`，足够覆盖一期需求

### 4.2 AgentResponse

文件建议：

- `com.nrec.service.basicagent.model.response.AgentResponse`

建议先做最小版：

```java
@Data
public class AgentResponse implements Serializable {

    private ChatMessage message;

    private Usage usage;

    @Data
    public static class Usage implements Serializable {
        private Integer promptTokens;
        private Integer completionTokens;
        private Integer totalTokens;
    }
}
```

### 4.3 AgentContext

文件建议：

- `com.nrec.service.basicagent.model.runtime.AgentContext`

建议字段：

```java
@Data
public class AgentContext implements Serializable {

    private String agentId;

    private AgentConfig config;

    private AgentRequest request;

    private Map<String, Object> promptVariables;

    private Boolean knowledgeEnabled;
}
```

说明：

- `promptVariables` 用于知识增强场景的延迟渲染

## 5. 聊天消息模型

### 5.1 ChatMessage

文件建议：

- `com.nrec.service.basicagent.model.chat.ChatMessage`

建议字段：

```java
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChatMessage implements Serializable {

    private MessageRole role;

    @Builder.Default
    private ContentType contentType = ContentType.TEXT;

    private Object content;

    private String name;
}
```

### 5.2 MessageRole

```java
public enum MessageRole {
    SYSTEM,
    USER,
    ASSISTANT
}
```

### 5.3 ContentType

```java
public enum ContentType {
    TEXT,
    MULTIMODAL
}
```

## 6. 配置编解码

### 6.1 AgentConfigCodec

文件建议：

- `com.nrec.service.basicagent.service.config.AgentConfigCodec`

方法签名建议：

```java
public interface AgentConfigCodec {

    AgentConfig parse(String configJson);

    String serialize(AgentConfig config);
}
```

### 6.2 AgentConfigCodecImpl

文件建议：

- `com.nrec.service.basicagent.service.config.impl.AgentConfigCodecImpl`

实现建议：

- 统一使用 Jackson
- `null` / 空串时返回空对象或 `null`
- 解析异常抛出明确业务异常

建议方法：

```java
@Service
public class AgentConfigCodecImpl implements AgentConfigCodec {

    @Override
    public AgentConfig parse(String configJson) { ... }

    @Override
    public String serialize(AgentConfig config) { ... }
}
```

用途：

- 版本保存前校验结构
- 版本查询时反序列化
- 执行前装载 `AgentContext.config`

## 7. 变量解析层

### 7.1 PromptVariableResolver

文件建议：

- `com.nrec.service.basicagent.service.prompt.PromptVariableResolver`

方法签名建议：

```java
public interface PromptVariableResolver {

    Map<String, Object> resolve(AgentConfig config, AgentRequest request);
}
```

### 7.2 PromptVariableResolverImpl

文件建议：

- `com.nrec.service.basicagent.service.prompt.impl.PromptVariableResolverImpl`

核心逻辑必须对齐 admin：

1. 遍历 `config.getPromptVariables()`
2. 写入 `name -> defaultValue`
3. 遍历 `request.getPromptVariables()`
4. 仅在变量已声明时覆盖
5. 删除空值和空白值

建议实现框架：

```java
@Service
public class PromptVariableResolverImpl implements PromptVariableResolver {

    @Override
    public Map<String, Object> resolve(AgentConfig config, AgentRequest request) {
        Map<String, Object> resolved = new HashMap<>();

        List<AgentConfig.PromptVariable> declared = config == null ? null : config.getPromptVariables();
        if (declared != null) {
            for (AgentConfig.PromptVariable variable : declared) {
                if (StringUtils.isNotBlank(variable.getName())) {
                    resolved.put(variable.getName(), variable.getDefaultValue());
                }
            }
        }

        Map<String, String> overrides = request == null ? null : request.getPromptVariables();
        if (overrides != null) {
            for (Map.Entry<String, String> entry : overrides.entrySet()) {
                if (resolved.containsKey(entry.getKey())) {
                    resolved.put(entry.getKey(), entry.getValue());
                }
            }
        }

        resolved.entrySet().removeIf(entry -> {
            Object value = entry.getValue();
            return value == null || StringUtils.isBlank(String.valueOf(value));
        });

        return resolved;
    }
}
```

## 8. 提示词模板服务

### 8.1 PromptTemplateService

文件建议：

- `com.nrec.service.basicagent.service.prompt.PromptTemplateService`

方法签名建议：

```java
public interface PromptTemplateService {

    String render(String instructions, Map<String, Object> variables);

    String renderWithDocuments(String instructions, Map<String, Object> variables, String documents);
}
```

### 8.2 PromptTemplateServiceImpl

文件建议：

- `com.nrec.service.basicagent.service.prompt.impl.PromptTemplateServiceImpl`

实现建议：

- 普通场景直接渲染变量
- 知识场景额外注入 `documents`
- 缺失 `{documents}` 时抛出异常

建议实现框架：

```java
@Service
public class PromptTemplateServiceImpl implements PromptTemplateService {

    @Override
    public String render(String instructions, Map<String, Object> variables) { ... }

    @Override
    public String renderWithDocuments(String instructions, Map<String, Object> variables, String documents) { ... }
}
```

实现细节建议：

- 若项目已引入 Spring AI，可直接用 `SystemPromptTemplate`
- 若当前模块尚未引入 Spring AI，可先用占位替换实现最小版本
- 最终建议仍统一到 Spring AI 的 prompt template 体系

## 9. 知识增强层

### 9.1 KnowledgePromptAugmentor

文件建议：

- `com.nrec.service.basicagent.service.knowledge.KnowledgePromptAugmentor`

方法签名建议：

```java
public interface KnowledgePromptAugmentor {

    String augment(String instructions, AgentContext context, String documents);
}
```

### 9.2 KnowledgePromptAugmentorImpl

职责：

- 从 `context.getPromptVariables()` 读取已解析变量
- 把 `{documents}` 合并进去
- 调用 `PromptTemplateService.renderWithDocuments(...)`

建议实现框架：

```java
@Service
public class KnowledgePromptAugmentorImpl implements KnowledgePromptAugmentor {

    @Override
    public String augment(String instructions, AgentContext context, String documents) { ... }
}
```

说明：

- 若一期尚未接知识库，这个类可以先定义接口和空实现
- 一旦接知识检索，直接挂接这层即可

## 10. 执行器设计

### 10.1 BasicAgentExecutor

文件建议：

- `com.nrec.service.basicagent.executor.BasicAgentExecutor`

一期不必一次做到完整 tool call，只需先承载提示词能力。

建议方法签名：

```java
public interface BasicAgentExecutor {

    AgentResponse execute(AgentContext context);
}
```

或直接类实现：

```java
@Service
public class BasicAgentExecutor {

    public AgentResponse execute(AgentContext context) { ... }

    protected List<Object> buildMessages(AgentContext context) { ... }

    protected String buildInstructions(AgentContext context, String instructions) { ... }
}
```

### 10.2 buildInstructions 逻辑建议

普通场景：

1. 读取 `config.instructions`
2. 调用 `PromptVariableResolver.resolve(...)`
3. 调用 `PromptTemplateService.render(...)`
4. 得到最终 system prompt

知识增强场景：

1. 读取 `config.instructions`
2. 调用 `PromptVariableResolver.resolve(...)`
3. 将变量缓存到 `context.promptVariables`
4. 暂不渲染最终字符串
5. 后续知识增强器负责注入 `{documents}`

## 11. 与现有版本服务的衔接

### 11.1 保存版本前

在 `AgentAppVersionServiceImpl.saveVersion(...)` 中建议增加：

- 将 `request.getConfig()` 解析成 `AgentConfig`
- 校验 `instructions`、`promptVariables` 结构是否合法
- 再序列化后写库

建议新增校验方法：

```java
private void validateAgentConfig(AgentConfig config) { ... }
```

建议校验项：

- `promptVariables.name` 不允许为空
- 变量名不允许重复
- 若有知识增强配置且启用 citation/documents 注入，`instructions` 应支持 `{documents}`

### 11.2 查询版本时

当前返回仍可保留 `config` 字符串，不强制改接口。

但内部建议提供辅助方法：

```java
public AgentConfig getParsedConfig(String agentId, String version) { ... }
```

## 12. 最小测试清单

### 12.1 PromptVariableResolver 测试

- 无声明变量时返回空 map
- 仅默认值时可正确返回
- 请求可覆盖已声明变量
- 请求不能注入未声明变量
- 空白值会被移除

### 12.2 PromptTemplateService 测试

- 普通变量可正确渲染
- 缺失变量时行为符合预期
- `{documents}` 可正确注入
- 缺失 `{documents}` 占位符时抛错

### 12.3 AgentConfigCodec 测试

- `config` JSON 可正确解析
- 再序列化后结构不丢字段

### 12.4 版本流转测试

- 草稿保存的 `instructions/promptVariables` 发布后仍存在
- 发布版本切回草稿后仍能完整恢复

## 13. 最小落地步骤

建议按下面顺序编码：

1. 新增 `AgentConfig`
2. 新增 `AgentConfigCodec`
3. 在版本保存链路里引入 `AgentConfig` 解析校验
4. 新增 `AgentRequest / AgentContext`
5. 新增 `PromptVariableResolver`
6. 新增 `PromptTemplateService`
7. 新增最小版 `BasicAgentExecutor`
8. 增加单元测试

## 14. 一期交付边界

一期完成即可视为“提示词及变量能力具备”：

- `config` 中可稳定保存 `instructions`
- `config` 中可稳定保存 `promptVariables`
- 运行时能根据默认值和请求值生成最终变量 map
- 普通场景能渲染最终 system prompt
- 知识增强场景预留 `{documents}` 延迟渲染能力

二期再补：

- 真实知识库检索接入
- 完整 `ChatClient/ChatModel` 执行
- Prompt build log
- Tool calling 和多轮记忆
