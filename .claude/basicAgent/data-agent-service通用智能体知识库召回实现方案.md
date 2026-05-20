# data-agent-service通用智能体知识库召回实现方案

## 1. 目标

在 `data-agent-service` 中补齐通用智能体的知识库召回能力，使其具备与 `spring-ai-alibaba-admin` 中 `basicAgent` 类似的运行时能力：

- 根据智能体绑定的知识库资源自动决定是否启用召回
- 在模型调用前执行知识检索
- 将召回结果注入到系统提示词中的 `{documents}` 占位符
- 保留版本、发布、复制、切换场景下的知识绑定治理能力
- 为后续扩展数据源召回、混合召回、引用标注、重排等能力预留接口

## 2. 现状分析

### 2.1 `spring-ai-alibaba-admin` 已有能力

`spring-ai-alibaba-admin` 的知识召回链路已经完整打通，核心特点如下：

- 在执行器中判断 `fileSearch.enableSearch` 和 `kbIds`
- 通过 `DocumentRetrieverManager` 构造 `DocumentRetriever`
- 通过 `KnowledgeBaseRetrievalAdvisor` 在模型调用前执行检索
- 将召回内容注入 system prompt 的 `{documents}` 占位符
- 将检索请求和检索结果写入 response metadata，便于前端展示

可参考的关键实现：

- `spring-ai-alibaba-admin-server-core/.../BasicAgentExecutor.java`
- `spring-ai-alibaba-admin-server-core/.../DocumentRetrieverManager.java`
- `spring-ai-alibaba-admin-server-core/.../KnowledgeBaseRetrievalAdvisor.java`
- `spring-ai-alibaba-admin-server-core/.../KnowledgeBaseDocumentRetriever.java`

### 2.2 `data-agent-service` 当前状态

`data-agent-service` 目前具备以下基础能力，但尚未形成完整运行时召回链路：

1. `agent-designer` 已具备知识增强配置模型
   - `AgentConfig.KnowledgeConfig`
   - 校验 `instructions` 中必须包含 `{documents}`

2. `agent-designer` 已具备知识绑定和发布快照能力
   - 保存版本时校验知识配置
   - 发布时将知识绑定固化进快照
   - 切换版本和复制应用时同步知识绑定

3. `capability-component` 已具备知识库接入能力
   - `KnowledgeController`
   - `DifyApiService`
   - 可对 Dify dataset 发起 retrieve

4. `BasicAgentExecutor` 尚未真正接入知识检索
   - 目前只做 prompt 变量渲染
   - `KnowledgePromptAugmentor` 只负责渲染，不负责检索
   - 运行时没有 advisor/retriever 风格的知识注入步骤

## 3. 总体设计

建议采用“设计器配置 + 资源绑定治理 + 运行时召回增强”的分层方案。

分层如下：

1. `agent-designer`
   - 负责智能体知识召回配置模型
   - 负责版本、快照、发布、复制、切换时的绑定同步

2. `capability-component`
   - 负责知识库资源管理
   - 负责知识检索执行
   - 负责统一知识检索结果结构

3. 运行时执行层
   - 在 `BasicAgentExecutor` 中新增知识召回编排
   - 在真正调用 LLM 前完成检索和 prompt 注入

## 4. 关键设计原则

### 4.1 配置与绑定分离

知识召回是否启用、TopK、阈值、是否重排等属于“智能体配置”；实际使用哪些知识库属于“资源绑定”。

建议继续保持当前模式：

- `AgentConfig.KnowledgeConfig` 保存行为参数
- `AgentResourceBindingService` 保存实际绑定资源

### 4.2 运行时只消费“当前上下文”

运行时不要直接依赖设计器页面状态，而应统一从 `AgentContext` 中读取：

- 当前生效的 `AgentConfig`
- 当前 `agentId`
- 当前用户请求
- 当前版本快照还原后的可执行信息

### 4.3 检索逻辑下沉到能力层

`BasicAgentExecutor` 不应该直接写 Dify API 调用逻辑。应将知识召回能力封装为独立服务，例如：

- `KnowledgeRetrievalService`
- `KnowledgePromptAdvisor` 或 `KnowledgeRetrievalAugmentor`

这样可以复用到：

- 同步调用
- 流式调用
- 后续工作流节点
- 其他类型智能体

## 5. 推荐落地结构

建议在 `agent-designer` 增加以下运行时服务：

### 5.1 新增知识召回服务接口

建议新增：

- `com.nrec.service.basicagent.service.knowledge.KnowledgeRetrievalService`

职责：

- 根据 `AgentContext` 判断是否启用知识召回
- 解析智能体当前绑定的知识库资源
- 调用 `capability-component` 的知识检索能力
- 统一返回检索结果

建议接口示例：

```java
public interface KnowledgeRetrievalService {

    boolean enabled(AgentContext context);

    KnowledgeRetrievalResult retrieve(AgentContext context, String query);

}
```

### 5.2 新增知识召回结果模型

建议新增：

- `KnowledgeRetrievalResult`
- `KnowledgeDocument`

建议字段：

```java
@Data
@Builder
public class KnowledgeRetrievalResult {
    private Boolean enabled;
    private String query;
    private List<KnowledgeDocument> documents;
    private String mergedDocuments;
}
```

```java
@Data
@Builder
public class KnowledgeDocument {
    private String datasetId;
    private String datasetName;
    private String documentId;
    private String segmentId;
    private String content;
    private Double score;
    private Map<String, Object> metadata;
}
```

### 5.3 新增知识召回增强器

建议新增：

- `KnowledgePromptAdvisor`
  或
- `KnowledgePromptRuntimeAugmentor`

职责：

- 先执行知识检索
- 再调用 `KnowledgePromptAugmentor`
- 最终生成注入 `{documents}` 后的 system prompt

这样可以保持现有 `KnowledgePromptAugmentor` 只负责模板渲染，不破坏职责边界。

## 6. 运行时链路设计

建议将 `BasicAgentExecutor` 的运行时链路调整为如下顺序：

1. 读取 `AgentContext`
2. 解析 prompt variables
3. 判断是否开启知识召回
4. 若开启：
   - 查询知识绑定
   - 对绑定知识库执行检索
   - 合并召回文本
   - 生成最终 system prompt
5. 组装消息列表
6. 调用 `ChatClient`
7. 返回结果

建议改造后的伪代码如下：

```java
public AgentResponse execute(AgentContext context) {
    ToolCallingChatOptions chatOptions = aiModelRegistry.buildChatOptions();

    String instructions = getInstructions(context);
    Map<String, Object> variables = promptVariableResolver.resolve(context.getConfig(), context.getRequest());
    context.setPromptVariables(variables);

    if (knowledgeRetrievalService.enabled(context)) {
        KnowledgeRetrievalResult retrievalResult =
                knowledgeRetrievalService.retrieve(context, extractUserQuery(context));
        instructions = knowledgePromptAugmentor.augment(
                instructions,
                context,
                retrievalResult.getMergedDocuments()
        );
    } else {
        instructions = promptTemplateService.render(instructions, variables);
    }

    List<Message> messages = buildMessagesWithResolvedInstructions(context, instructions);
    Prompt prompt = new Prompt(messages, chatOptions);
    ChatResponse response = chatClientBuilder.build().prompt(prompt).options(chatOptions).call().chatResponse();
    return convertResponse(response).block();
}
```

## 7. 知识检索服务实现建议

### 7.1 启用判断逻辑

启用条件建议同时满足以下条件：

1. `AgentConfig.KnowledgeConfig.enabled == true`
2. 当前 agent 存在 `ResourceType.KNOWLEDGE` 绑定
3. `instructions` 包含 `{documents}`

其中第 3 点当前保存版本时已经做了校验，但运行时仍建议保底判断。

### 7.2 查询绑定资源

通过现有服务：

- `AgentResourceBindingService.listBindings(agentId, ResourceType.KNOWLEDGE)`

获取当前智能体绑定的知识库列表。

绑定返回的核心信息至少要提取：

- `resourceId`
- `resourceName`
- `params`
- `metaData`

### 7.3 发起知识检索

底层仍复用 `capability-component` 的 Dify 检索能力：

- `DifyApiService.retrieveFromDataset(datasetId, request)`

建议由 `KnowledgeRetrievalServiceImpl` 负责把 `KnowledgeConfig` 映射成 Dify 请求对象：

- `topK`
- `threshold`
- `enableRerank`
- 其他检索参数

### 7.4 多知识库策略

建议第一阶段采用“串行检索 + 汇总排序”。

流程：

1. 遍历所有绑定 dataset
2. 每个 dataset 调用一次 retrieve
3. 将返回的片段标准化为统一 `KnowledgeDocument`
4. 按 score 倒序
5. 按 `knowledgeConfig.topK` 做总截断

后续可升级为并发检索。

### 7.5 文档拼接策略

建议统一做一个文档拼接器，避免后续多处重复处理。

拼接格式建议：

```text
[知识库: 数据集A]
1. xxx
2. xxx

[知识库: 数据集B]
1. xxx
2. xxx
```

这样便于：

- 模型区分来源
- 后续扩展 citation
- 前端展示召回上下文

## 8. 对现有类的具体改造建议

### 8.1 改造 `BasicAgentExecutor`

文件：

- `agent-designer/.../executor/BasicAgentExecutor.java`

改造点：

1. 注入 `KnowledgeRetrievalService`
2. 修复当前 `buildInstructions(...)` 中无效的 `String.format(...)`
3. 把知识增强从“只判断绑定”升级为“真正检索后再注入”
4. 为同步/流式执行统一复用同一套知识增强逻辑

注意：

当前这段代码：

```java
if (hasKnowledgeBindings(context)) {
    String.format(aiDesignerProperties.getFileSearchPrompt(), instructions);
}
```

没有接收返回值，实际上没有生效，应修复。

### 8.2 改造 `KnowledgePromptAugmentor`

保留现有接口职责，只负责：

- 使用 `PromptTemplateService.renderWithDocuments(...)`
- 将 documents 注入到 `{documents}`

不建议把远程检索调用塞进该类中。

### 8.3 新增 `KnowledgeRetrievalServiceImpl`

建议依赖：

- `AgentResourceBindingService`
- `DifyApiService`

可选依赖：

- `AgentDesignerProperties`
- 日志组件

职责：

- 判断是否开启
- 拉取绑定
- 构造检索请求
- 多 dataset 检索
- 结果汇总

### 8.4 新增运行时消息构造方法

建议将 `buildMessages(...)` 拆分为两层：

1. `resolveInstructions(...)`
2. `buildMessages(...)`

这样可以避免在 `buildMessages(...)` 内部混入太多知识增强逻辑。

## 9. 与快照/发布链路的协同方式

当前快照链路建议保留，不需要推翻。

建议运行时优先级如下：

1. 使用当前版本可编辑配置中的 `knowledgeConfig`
2. 使用当前 agent 的实时绑定资源
3. 发布态场景可从快照中恢复绑定并同步到绑定表

这样可以保证：

- 设计态和发布态一致
- 复制、回滚、切换版本后知识绑定不丢失
- 运行时不直接解析复杂快照结构

## 10. 接口和模型扩展建议

### 10.1 `AgentResponse` 增加检索上下文

建议为后续调试和前端展示保留知识召回信息，例如：

```java
private KnowledgeRetrievalTrace retrievalTrace;
```

可包含：

- 是否开启知识检索
- 命中的 dataset
- 命中的片段数
- 最终注入的文档长度

### 10.2 流式场景的扩展

当前 `streamExecute(...)` 可以先做知识检索，再开始流式输出。

推荐第一阶段采用：

- 先同步检索
- 再发起流式模型调用

不建议第一阶段就实现“检索中间事件流”，因为复杂度明显更高。

## 11. 分阶段实施计划

### 第一阶段：最小可用版本

目标：

- 通用智能体具备基本知识召回能力

实施内容：

1. 新增 `KnowledgeRetrievalService`
2. 在 `BasicAgentExecutor` 中接入知识检索
3. 基于知识绑定调用 Dify retrieve
4. 把结果注入 `{documents}`
5. 同步执行和流式执行共用同一套增强逻辑

### 第二阶段：增强可观测性

目标：

- 前端可看见“本次调用检索了什么”

实施内容：

1. 为 `AgentResponse` 增加检索trace
2. 记录命中的知识库、片段和分数
3. 暴露调试字段给前端

### 第三阶段：能力增强

目标：

- 提升召回效果和扩展能力

实施内容：

1. 多知识库并发检索
2. 统一 rerank
3. 文档长度裁剪
4. citation 输出
5. 支持知识库 + 数据源 schema 混合召回

## 12. 推荐改造清单

建议新增文件：

- `agent-designer/.../service/knowledge/KnowledgeRetrievalService.java`
- `agent-designer/.../service/knowledge/impl/KnowledgeRetrievalServiceImpl.java`
- `agent-designer/.../model/knowledge/KnowledgeRetrievalResult.java`
- `agent-designer/.../model/knowledge/KnowledgeDocument.java`

建议改造文件：

- `agent-designer/.../executor/BasicAgentExecutor.java`
- `agent-designer/.../service/knowledge/impl/KnowledgePromptAugmentorImpl.java`
- `agent-designer/.../model/response/AgentResponse.java`

可复用文件：

- `agent-designer/.../service/prompt/PromptTemplateService.java`
- `agent-designer/.../service/prompt/impl/PromptVariableResolverImpl.java`
- `capability-component/.../service/knowledge/DifyApiService.java`
- `capability-component/.../service/impl/AgentResourceBindingServiceImpl.java`

## 13. 风险与注意事项

### 13.1 当前执行器里知识增强代码不完整

`BasicAgentExecutor` 当前只是“判断是否有知识绑定”，并没有实际调用知识召回。改造时不要在原有方法上继续堆逻辑，应直接抽出独立运行时服务。

### 13.2 Dify 返回结构需要统一标准化

不同 dataset 的 retrieve 结果字段可能存在差异，必须在 `KnowledgeRetrievalServiceImpl` 中统一转换，避免后续 prompt 注入层感知第三方结构。

### 13.3 多知识库结果总量需要限制

如果多个 dataset 同时命中，拼接后的 `{documents}` 很容易过长。建议至少加入：

- 总条数限制
- 总字符数限制
- 空结果兜底逻辑

### 13.4 运行时不要直接依赖前端传入的 datasetId

应优先使用智能体绑定关系，避免出现“请求层参数覆盖绑定层约束”的不一致问题。

## 14. 最终建议

推荐按以下路线实现：

1. 保留 `agent-designer` 当前的配置、绑定、快照、发布体系
2. 在 `agent-designer` 中补充运行时知识召回服务
3. 检索能力复用 `capability-component` 的 Dify 接口
4. 由 `BasicAgentExecutor` 在模型调用前统一执行“检索 -> 注入 -> 调用”
5. 第一阶段先实现同步检索注入，第二阶段再补 trace 和引用展示

按此方案改造后，`data-agent-service` 会同时具备：

- 类似 `spring-ai-alibaba-admin` 的完整知识召回运行时能力
- 比 `spring-ai-alibaba-admin` 更强的版本治理、资源绑定和发布快照能力

