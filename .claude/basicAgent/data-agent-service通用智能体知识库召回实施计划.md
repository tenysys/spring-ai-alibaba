# data-agent-service通用智能体知识库召回实施计划

## 1. 文档目的

本文档用于将 `data-agent-service` 通用智能体知识库召回方案落成具体实施计划。  
本计划基于两部分内容：

- `.claude/basicAgent/data-agent-service通用智能体知识库召回实现方案.md`
- `spring-ai-alibaba-admin` 模块中 `basicAgent` 的知识召回实现

本文重点不是再次描述架构，而是明确：

- 需要新增和改造哪些类
- 如何补齐运行时召回链路
- 如何引入多知识库并发检索
- 如何测试与验收

## 2. 实施目标

本次实施完成后，`data-agent-service` 中的通用智能体应具备以下能力：

1. 当智能体开启知识增强且绑定知识库资源时，模型调用前自动执行知识检索
2. 将召回结果注入到系统提示词中的 `{documents}` 占位符
3. 同步调用和流式调用共用同一套知识增强逻辑
4. 支持多知识库并发检索
5. 多知识库结果可统一归并、排序、截断并注入 prompt
6. 支持部分知识库失败时继续使用成功结果
7. 为后续 citation、trace、混合召回保留结构

## 3. 当前代码现状

### 3.1 `spring-ai-alibaba-admin` 的现成实现

`spring-ai-alibaba-admin` 中 `basicAgent` 的知识召回已经形成完整运行时链路，关键特点：

1. 在执行器中识别知识检索配置
2. 使用 `DocumentRetrieverManager` 创建 retriever
3. 使用 `KnowledgeBaseRetrievalAdvisor.before(...)` 在模型调用前执行检索
4. 将 `documents` 与 prompt variables 一起渲染 system prompt
5. 将检索上下文写入 metadata
6. 对流式与非流式场景分别做适配

关键参考点：

- `BasicAgentExecutor.buildChatClient(...)`
- `KnowledgeBaseRetrievalAdvisor.before(...)`
- `KnowledgeBaseRetrievalAdvisor.after(...)`
- `KnowledgeBaseRetrievalAdvisor.adviseStream(...)`

### 3.2 `data-agent-service` 当前已具备的能力

#### `agent-designer`

已具备：

- `AgentConfig.KnowledgeConfig`
- 版本保存时对 `{documents}` 占位符的校验
- 知识绑定快照的发布、切换、复制同步
- `KnowledgePromptAugmentor` 的模板注入能力

缺失：

- 运行时真正的知识检索服务
- 多知识库归并逻辑
- 同步与流式调用中的知识注入编排
- 检索 trace 输出

#### `capability-component`

已具备：

- `KnowledgeController`
- `DifyApiService`
- `DifyRetrieveRequest`
- `DifyRetrieveResponse`
- `AgentResourceBindingService`

缺失：

- 面向 `agent-designer` 运行时的统一知识检索适配层
- 多知识库并发检索结果归并层

## 4. 本次实施范围

本次实施范围限定在以下模块：

- `E:/java/workplace/data-agent-service/agent-designer`
- `E:/java/workplace/data-agent-service/capability-component`

本次不做：

- 不改前端页面交互
- 不改知识库绑定表结构
- 不实现 citation 最终展示
- 不实现知识库与数据源 schema 的混合召回
- 不改发布/快照总体结构

## 5. 实施总路线

本次实施采用三层补齐方案：

1. `agent-designer` 新增运行时知识检索服务
2. `BasicAgentExecutor` 补齐模型调用前的知识增强编排
3. 复用 `capability-component` 的 Dify 检索能力，并新增多知识库并发归并逻辑

整体顺序如下：

1. 定义运行时知识模型
2. 定义知识检索服务接口
3. 实现单知识库检索适配
4. 实现多知识库并发检索
5. 实现统一结果归并
6. 改造同步执行链路
7. 改造流式执行链路
8. 增加 trace 输出
9. 完成测试和验收

## 6. 新增与改造类清单

### 6.1 建议新增类

#### 6.1.1 运行时知识检索服务接口

建议路径：

- `agent-designer/src/main/java/com/nrec/service/basicagent/service/knowledge/KnowledgeRetrievalService.java`

建议职责：

- 判断当前上下文是否需要知识召回
- 发起知识检索
- 返回统一结果

建议接口：

```java
public interface KnowledgeRetrievalService {

    boolean enabled(AgentContext context);

    KnowledgeRetrievalResult retrieve(AgentContext context, String query);

}
```

#### 6.1.2 运行时知识检索服务实现

建议路径：

- `agent-designer/src/main/java/com/nrec/service/basicagent/service/knowledge/impl/KnowledgeRetrievalServiceImpl.java`

依赖建议：

- `AgentResourceBindingService`
- `DifyApiService`
- `AsyncTaskExecutor` 或项目统一线程池

职责：

- 读取 `KnowledgeConfig`
- 查询知识库绑定
- 为每个绑定 dataset 构造 retrieve request
- 并发执行多知识库检索
- 合并并排序结果
- 拼装 `mergedDocuments`

#### 6.1.3 运行时数据模型

建议新增：

- `KnowledgeRetrievalResult`
- `KnowledgeDocument`
- `KnowledgeRetrievalTrace`
- `DatasetRetrievalResult`

建议路径：

- `agent-designer/src/main/java/com/nrec/service/basicagent/model/knowledge/...`

作用：

- 屏蔽 Dify 原始结构
- 统一表达结果
- 支撑 trace、验收和后续 citation 扩展

### 6.2 建议改造类

#### 6.2.1 `BasicAgentExecutor`

文件：

- `agent-designer/.../executor/BasicAgentExecutor.java`

改造重点：

1. 注入 `KnowledgeRetrievalService`
2. 将 prompt 变量解析和知识增强编排拆开
3. 同步和流式都走统一的 `resolveInstructions(...)`
4. 修复当前 `String.format(...)` 调用无效的问题

当前问题代码：

```java
if (hasKnowledgeBindings(context)) {
    String.format(aiDesignerProperties.getFileSearchPrompt(), instructions);
}
return promptTemplateService.render(instructions, resolvedVariables);
```

这段逻辑没有真正修改 `instructions`，实际并未完成知识增强。

#### 6.2.2 `AgentContext`

文件：

- `agent-designer/.../model/runtime/AgentContext.java`

建议新增字段：

```java
private KnowledgeRetrievalTrace knowledgeRetrievalTrace;
```

#### 6.2.3 `AgentResponse`

文件：

- `agent-designer/.../model/response/AgentResponse.java`

建议新增字段：

```java
private KnowledgeRetrievalTrace retrievalTrace;
```

#### 6.2.4 `KnowledgePromptAugmentor`

文件：

- `agent-designer/.../service/knowledge/KnowledgePromptAugmentor.java`
- `agent-designer/.../service/knowledge/impl/KnowledgePromptAugmentorImpl.java`

结论：

- 保持职责不变
- 只负责将 `documents` 注入到 `{documents}`
- 不在这里写远程检索和并发逻辑

## 7. 运行时链路改造方案

### 7.1 同步执行链路

目标时序：

```text
AgentContext
-> resolvePromptVariables
-> knowledgeRetrievalService.enabled
-> knowledgeRetrievalService.retrieve
-> knowledgePromptAugmentor.augment
-> buildMessages
-> ChatClient.call
-> convertResponse
```

建议流程：

1. 从 `AgentContext` 中取 `AgentConfig` 和 `AgentRequest`
2. 解析 prompt variables，并回填到 `context`
3. 判断是否开启知识增强
4. 如果开启：
   - 查询绑定的 dataset
   - 并发检索
   - 归并结果
   - 调用 `KnowledgePromptAugmentor`
5. 用增强后的 instructions 构造 system message
6. 发起模型调用
7. 将 trace 注入 `AgentResponse`

### 7.2 流式执行链路

第一阶段建议：

- 流式输出前先完成一次同步检索
- 把最终 instructions 固定下来
- 后续 token 流只负责模型输出

这样做的原因：

- 最容易与当前 `streamExecute(...)` 结构兼容
- 不需要额外模拟 file-search 中间事件流
- 可以和同步执行复用同一套知识增强逻辑

## 8. 多知识库并发检索实施方案

### 8.1 功能目标

多知识库并发检索的目标是：

1. 减少多个 dataset 串行检索带来的总耗时
2. 保持单知识库失败时整体请求可继续
3. 将多个知识库结果统一归并为一个 prompt 注入结果

### 8.2 并发执行位置

并发逻辑建议只放在：

- `KnowledgeRetrievalServiceImpl.retrieve(...)`

不建议把并发逻辑写到 `BasicAgentExecutor` 中，原因：

- 执行器只负责编排，不负责检索细节
- 检索服务更容易测试
- 后续工作流节点也可复用

### 8.3 并发执行器选择

建议优先复用项目现有线程池，而不是直接使用 `ForkJoinPool.commonPool()`。

推荐候选：

- `capabilityTaskExecutor`

原因：

1. `capability-component` 中已有异步线程池使用模式
2. 统一线程池便于管理和监控
3. 后续配置化更方便

建议并发调用形式：

```java
CompletableFuture.supplyAsync(
    () -> retrieveSingleDataset(...),
    taskExecutor
)
```

### 8.4 单知识库检索单元

建议在 `KnowledgeRetrievalServiceImpl` 中拆出：

- `retrieveSingleDataset(...)`

职责：

1. 接收 `datasetId / datasetName / query / knowledgeConfig`
2. 构造 `DifyRetrieveRequest`
3. 调用 `difyApiService.retrieveFromDataset(...)`
4. 转换结果为 `KnowledgeDocument`
5. 返回 `DatasetRetrievalResult`

建议中间模型：

```java
@Data
@Builder
public class DatasetRetrievalResult {
    private String datasetId;
    private String datasetName;
    private boolean success;
    private String errorMessage;
    private long elapsedMs;
    private List<KnowledgeDocument> documents;
}
```

### 8.5 并发执行流程

建议流程：

1. 使用 `AgentResourceBindingService.listBindings(agentId, ResourceType.KNOWLEDGE)` 获取绑定列表
2. 过滤无效 dataset
3. 为每个 dataset 构造一个 `CompletableFuture<DatasetRetrievalResult>`
4. 并发发起多个 Dify retrieve
5. 使用 `CompletableFuture.allOf(...)` 等待
6. 收集所有结果
7. 保留失败结果到 trace
8. 归并成功结果中的 documents

建议伪代码：

```java
List<CompletableFuture<DatasetRetrievalResult>> futures = bindings.stream()
        .map(binding -> CompletableFuture.supplyAsync(
                () -> retrieveSingleDataset(binding, query, knowledgeConfig),
                taskExecutor))
        .toList();

CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();

List<DatasetRetrievalResult> datasetResults = futures.stream()
        .map(CompletableFuture::join)
        .toList();
```

### 8.6 失败处理原则

并发检索必须支持部分失败。

建议规则：

1. 单个 dataset 失败时，不抛出全局异常
2. 失败任务返回 `success=false`
3. 只要至少一个 dataset 成功，就继续生成 prompt
4. 全部失败时：
   - 允许按空结果继续
   - trace 中记录失败详情

建议每个任务内部自己兜底，而不是依赖 `allOf()` 抛异常：

```java
private DatasetRetrievalResult retrieveSingleDataset(...) {
    try {
        ...
        return successResult;
    } catch (Exception ex) {
        return failedResult;
    }
}
```

### 8.7 超时控制

多知识库并发检索建议同时考虑：

1. 单知识库超时
2. 总等待超时

第一阶段如不便配置化，可先使用默认固定值。后续再增加配置项，例如：

- `retrieveTimeoutMs`
- `overallRetrieveTimeoutMs`
- `maxConcurrentDatasets`

### 8.8 结果归并策略

多知识库检索结果建议统一按全局排序归并，而不是每库先截断后再拼接。

建议规则：

1. 汇总所有成功 dataset 的 `KnowledgeDocument`
2. 按 `score` 倒序
3. `score` 相同按稳定顺序排序
4. 全局截断到 `knowledgeConfig.topK`
5. 生成最终 `mergedDocuments`

不建议当前阶段采用：

- 每个 dataset 各自保留 topK 后再平均混排

因为这会引入额外均衡策略，复杂度更高。

### 8.9 文档拼接规则

推荐格式：

```text
[知识库: 设备知识库]
1. 变压器的额定容量...

[知识库: 运维规程库]
2. 主变巡视周期...
```

拼接原则：

- 显示来源知识库名称
- 按最终全局顺序拼接
- 片段间使用双换行分隔

### 8.10 空结果处理

当最终没有任何可用 documents 时：

1. 不抛错
2. 仍然允许继续调用模型
3. `documents` 注入为空字符串
4. `retrievalTrace` 中标记为：
   - enabled = true
   - hitCount = 0
   - datasetResults 包含失败/空结果信息

## 9. 方法级改造建议

### 9.1 `BasicAgentExecutor`

建议拆分或新增的方法：

- `resolvePromptVariables(AgentContext context)`
- `resolveInstructions(AgentContext context)`
- `extractUserQuery(AgentContext context)`
- `buildMessages(AgentContext context, String resolvedInstructions)`

建议修改的方法：

- `execute(...)`
- `streamExecute(...)`
- `buildMessages(...)`
- `buildInstructions(...)`

### 9.2 `KnowledgeRetrievalServiceImpl`

建议核心方法：

- `enabled(AgentContext context)`
- `retrieve(AgentContext context, String query)`
- `retrieveDatasetsConcurrently(...)`
- `retrieveSingleDataset(...)`
- `buildRetrieveRequest(...)`
- `mergeDatasetResults(...)`
- `buildMergedDocuments(...)`
- `buildTrace(...)`

### 9.3 `convertResponse(...)`

建议改造方向：

- 增加 `AgentContext` 参数
  或
- 在执行器层构建 `AgentResponse` 时补入 `retrievalTrace`

目标：

- 最终响应中可返回本次召回摘要

## 10. 分阶段实施计划

### 第一阶段：骨架接通

目标：

- 通用智能体首次具备运行时知识召回能力
- 多知识库并发检索纳入第一阶段，不再后置

任务：

1. 新增 `KnowledgeRetrievalService`
2. 新增 `KnowledgeRetrievalServiceImpl`
3. 新增 `KnowledgeDocument / KnowledgeRetrievalResult / DatasetRetrievalResult / KnowledgeRetrievalTrace`
4. 实现单知识库检索和结果标准化
5. 实现多知识库并发检索
6. 实现多知识库结果归并
7. 改造 `AgentContext`
8. 改造 `BasicAgentExecutor`
9. 改造 `AgentResponse`

交付标准：

- 绑定知识库后可在模型调用前注入知识
- `{documents}` 能成功替换
- 多知识库场景支持并发检索
- 同步与流式都可运行

### 第二阶段：可观测性补齐

目标：

- 前端或调试接口可看见知识检索摘要

任务：

1. 输出 `retrievalTrace`
2. 记录每个 dataset 的耗时
3. 记录每个 dataset 的成功/失败状态
4. 记录最终命中条数和注入长度

交付标准：

- 可区分单知识库、多知识库、部分失败、全部失败
- 可定位某个 dataset 的超时或异常

### 第三阶段：质量增强

目标：

- 提升召回效果和并发控制质量

任务：

1. 字符数裁剪
2. rerank 收敛
3. citation 结构预留
4. 并发度和超时参数配置化
5. 后续支持混合召回

交付标准：

- 不破坏第一阶段兼容性
- 不影响版本、快照和绑定同步逻辑

## 11. 测试计划

### 11.1 单元测试

#### `KnowledgeRetrievalServiceImplTest`

建议覆盖：

1. `knowledgeConfig.enabled=false` 时不检索
2. 无知识绑定时不检索
3. 单知识库成功时能返回正确结果
4. 多知识库并发时可合并成功结果
5. 多知识库全局 topK 截断生效
6. 单个 dataset 失败时不影响其他 dataset
7. 全部 dataset 失败时返回受控空结果
8. 空检索结果时 `mergedDocuments` 为空

#### `BasicAgentExecutorTest`

建议覆盖：

1. 普通 prompt 变量渲染不受影响
2. 有知识增强时最终 system prompt 包含 `documents`
3. 同步调用前先完成知识检索
4. 流式调用前先完成知识检索
5. 无知识绑定时执行器行为与旧逻辑一致

### 11.2 集成测试

建议至少覆盖四类场景。

#### 场景 1：无知识绑定

预期：

- 不调用 Dify retrieve
- prompt 仅使用变量渲染

#### 场景 2：单知识库检索

预期：

- 成功调用一个 dataset retrieve
- prompt 中注入召回内容

#### 场景 3：多知识库并发检索

预期：

- 一次请求触发多个 dataset 检索
- 最终结果按全局 score 排序
- 只保留全局 topK

#### 场景 4：多知识库部分失败

预期：

- 失败 dataset 不影响成功结果注入
- trace 中可以看到失败信息

### 11.3 回归测试

必须回归：

1. 创建应用
2. 保存草稿版本
3. 发布版本
4. 切换版本
5. 复制已发布应用

验证目标：

- 知识绑定不丢失
- 快照恢复正常
- 新增运行时并发检索不破坏治理链路

## 12. 验收标准

### 功能验收

1. 开启知识增强并绑定知识库后，模型调用前可自动检索知识
2. 检索结果能正确注入 `{documents}`
3. 支持多知识库并发检索
4. 支持部分知识库失败时继续使用成功结果
5. 同步和流式场景均可生效

### 代码验收

1. 检索逻辑集中在 `KnowledgeRetrievalServiceImpl`
2. `BasicAgentExecutor` 不直接耦合 Dify 原始结构
3. `KnowledgePromptAugmentor` 保持单一职责
4. 并发逻辑不散落在执行器中
5. 核心链路有测试覆盖

### 稳定性验收

1. 无绑定时执行器行为与改造前一致
2. 空检索结果不会导致模型调用失败
3. 单个知识库失败不会拖垮整个检索流程
4. 全部知识库失败时仍能受控返回

## 13. 风险与应对

### 风险 1：Dify 返回结构不稳定

应对：

- 在 `KnowledgeRetrievalServiceImpl` 中统一转换为内部标准模型

### 风险 2：召回文本过长

应对：

- 第一阶段先加全局 topK
- 第二阶段补字符长度裁剪

### 风险 3：并发检索线程池打满

应对：

- 优先复用受控线程池
- 限制单次智能体请求参与并发的知识库数量
- 后续把并发度配置化

### 风险 4：部分失败处理不当导致整体失败

应对：

- 每个 dataset 任务内部自行兜底并返回失败结果对象
- 归并阶段只消费成功结果

### 风险 5：同步和流式逻辑分叉

应对：

- 统一走 `resolveInstructions(context)`
- 不写两套知识增强逻辑

### 风险 6：快照与实时绑定不一致

应对：

- 运行时以当前绑定表为准
- 发布、切换、复制继续沿用现有同步逻辑

## 14. 推荐实施顺序

建议按以下顺序推进：

1. 新增知识检索运行时模型
2. 新增 `KnowledgeRetrievalService`
3. 实现单知识库检索适配
4. 实现多知识库并发检索
5. 实现统一归并与排序
6. 改造 `AgentContext`
7. 改造 `BasicAgentExecutor`
8. 改造 `AgentResponse`
9. 完成单元测试
10. 联调 Dify
11. 完成回归测试

## 15. 最终结论

本次实施不需要推翻 `data-agent-service` 当前的设计器、绑定和快照体系。  
最佳路径是：

- 保留 `agent-designer` 当前的配置与治理能力
- 复用 `capability-component` 的知识检索能力
- 在 `BasicAgentExecutor` 中补齐模型调用前的知识增强编排
- 在 `KnowledgeRetrievalServiceImpl` 中落地多知识库并发检索与结果归并

按本计划实施后，`data-agent-service` 将在保持现有版本治理优势的前提下，具备与 `spring-ai-alibaba-admin basicAgent` 对齐的知识库召回运行时能力，并额外支持多知识库并发检索。

