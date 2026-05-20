# 系统提示词及prompt变量实施计划

## 1. 目标

在现有代码基础上补齐 `instructions` 和 `promptVariables` 能力，并保证：

- 草稿态配置可保存 `instructions`
- 草稿态配置可保存 `promptVariables`
- 发布后快照中完整保留上述配置
- 从已发布版本切回草稿时可完整恢复
- 运行时可按“声明默认值 + 请求覆盖 + 未声明不可注入 + 空值过滤”的规则解析变量
- 为后续知识增强场景预留 `{documents}` 延迟渲染能力

## 2. 落地范围

结合现状，实施范围分为两层：

- 设计态管理层：当前真实落地模块是 `agent-designer`
- 运行时能力层：为后续 `BasicAgentExecutor` / prompt 渲染能力补齐模型和服务

说明：

- 前两份文档中多处写的是 `basic-agent`，但当前仓库实际对应模块是 `agent-designer`
- 当前计划以 `agent-designer` 为第一落地点，包路径仍沿用 `com.nrec.service.basicagent`

## 3. 当前代码现状

已存在能力：

- `[BasicAgentController](I:/java/workplace/data-agent-service/agent-designer/src/main/java/com/nrec/service/basicagent/controller/BasicAgentController.java)` 提供应用、版本、发布接口
- `[AgentAppVersionServiceImpl](I:/java/workplace/data-agent-service/agent-designer/src/main/java/com/nrec/service/basicagent/service/app/impl/AgentAppVersionServiceImpl.java)` 负责草稿保存、版本切换
- `[AgentPublishServiceImpl](I:/java/workplace/data-agent-service/agent-designer/src/main/java/com/nrec/service/basicagent/service/publish/impl/AgentPublishServiceImpl.java)` 负责发布
- `[AgentVersionSnapshotServiceImpl](I:/java/workplace/data-agent-service/agent-designer/src/main/java/com/nrec/service/basicagent/service/snapshot/impl/AgentVersionSnapshotServiceImpl.java)` 负责发布快照封装和草稿恢复

当前缺失能力：

- `config` 只有字符串存取，没有统一 `AgentConfig` 模型
- 保存版本时没有解析和校验 `instructions` / `promptVariables`
- 没有运行时 `AgentRequest / AgentResponse / AgentContext`
- 没有 `PromptVariableResolver`
- 没有 `PromptTemplateService`
- 没有面向执行链的 `BasicAgentExecutor`

## 4. 实施原则

- 不改动现有应用表、版本表结构
- `config` 继续以 JSON 字符串存储
- 配置存储与运行时渲染解耦
- 发布快照继续由 `AgentVersionSnapshotService` 统一封装
- 请求侧变量只允许覆盖已声明变量
- 一期先打通“保存、校验、恢复、普通变量渲染”最小闭环
- 二期再接知识增强延迟渲染和运行执行链

## 5. 目标产物

### 5.1 新增模型

建议新增：

- `com.nrec.service.basicagent.model.config.AgentConfig`
- `com.nrec.service.basicagent.model.request.AgentRequest`
- `com.nrec.service.basicagent.model.response.AgentResponse`
- `com.nrec.service.basicagent.model.runtime.AgentContext`
- `com.nrec.service.basicagent.model.chat.ChatMessage`
- `com.nrec.service.basicagent.enums.MessageRole`
- `com.nrec.service.basicagent.enums.ContentType`

### 5.2 新增服务

建议新增：

- `com.nrec.service.basicagent.service.config.AgentConfigCodec`
- `com.nrec.service.basicagent.service.config.impl.AgentConfigCodecImpl`
- `com.nrec.service.basicagent.service.prompt.PromptVariableResolver`
- `com.nrec.service.basicagent.service.prompt.impl.PromptVariableResolverImpl`
- `com.nrec.service.basicagent.service.prompt.PromptTemplateService`
- `com.nrec.service.basicagent.service.prompt.impl.PromptTemplateServiceImpl`
- `com.nrec.service.basicagent.service.knowledge.KnowledgePromptAugmentor`
- `com.nrec.service.basicagent.service.knowledge.impl.KnowledgePromptAugmentorImpl`

### 5.3 新增执行器

建议新增：

- `com.nrec.service.basicagent.executor.BasicAgentExecutor`

## 6. 分阶段执行计划

### 第一阶段：配置模型与编解码落地

目标：

- 建立统一 `AgentConfig`
- 建立 `config JSON <-> AgentConfig` 编解码入口
- 不影响现有版本保存和发布链路

实施任务：

1. 新增 `AgentConfig`
2. 在 `AgentConfig` 中定义以下稳定字段：
   - `instructions`
   - `promptVariables`
   - `knowledgeConfig`
   - 其他执行链预留字段
3. 新增 `AgentConfigCodec`
4. 使用 Jackson 实现 `parse(String)` 与 `serialize(AgentConfig)`
5. 约定空串、非法 JSON、空对象的处理规则

输出结果：

- 业务层不再直接把 `config` 当黑盒字符串使用
- 后续所有校验、渲染都基于 `AgentConfig`

### 第二阶段：版本保存链路接入配置校验

目标：

- 在不改接口形态的前提下，让版本保存逻辑识别 `instructions` 和 `promptVariables`

实施任务：

1. 修改 `[AgentAppVersionServiceImpl](I:/java/workplace/data-agent-service/agent-designer/src/main/java/com/nrec/service/basicagent/service/app/impl/AgentAppVersionServiceImpl.java)`
2. 在 `saveVersion(...)` 中增加：
   - `request.getConfig()` 解析为 `AgentConfig`
   - 调用统一校验方法
   - 校验通过后再序列化写回 `entity.setConfig(...)`
3. 新增 `validateAgentConfig(AgentConfig config)`，至少校验：
   - `promptVariables.name` 不为空
   - 变量名不重复
   - `instructions` 可以为空，但非空时必须是字符串
   - 若知识增强开启且要求文档注入，则模板必须包含 `{documents}`
4. 校验失败时抛出明确业务异常

输出结果：

- 草稿态已能稳定保存 `instructions` 和 `promptVariables`
- 无效配置会在保存阶段被拦截，而不是延迟到运行时暴露

### 第三阶段：快照与版本切换兼容验证

目标：

- 确认新增字段不会破坏发布和恢复链路

实施任务：

1. 验证 `[AgentPublishServiceImpl](I:/java/workplace/data-agent-service/agent-designer/src/main/java/com/nrec/service/basicagent/service/publish/impl/AgentPublishServiceImpl.java)` 无需改动表结构
2. 验证 `[AgentVersionSnapshotServiceImpl](I:/java/workplace/data-agent-service/agent-designer/src/main/java/com/nrec/service/basicagent/service/snapshot/impl/AgentVersionSnapshotServiceImpl.java)` 对 `config` 的封装仍保持透明
3. 补充测试用例覆盖：
   - 草稿保存
   - 发布快照
   - 从发布版本切回草稿
   - `instructions/promptVariables` 内容不丢失

输出结果：

- 发布态快照继续承载完整配置
- 草稿恢复仍使用现有 `extractEditableConfig(...)` 机制

### 第四阶段：运行时变量解析服务

目标：

- 实现普通场景的 prompt 变量解析闭环

实施任务：

1. 新增 `AgentRequest`
2. 新增 `AgentContext`
3. 新增 `PromptVariableResolver`
4. 按以下规则实现 `resolve(AgentConfig, AgentRequest)`：
   - 遍历 `config.promptVariables`
   - 写入 `name -> defaultValue`
   - 用 `request.promptVariables` 覆盖已声明变量
   - 忽略未声明变量
   - 删除 `null`、空串、空白值
5. 产出 `Map<String, Object>` 供模板渲染和知识增强复用

输出结果：

- 变量解析规则与前两份文档保持一致
- 后续执行器无需再关心变量合并细节

### 第五阶段：提示词模板渲染服务

目标：

- 完成 `instructions` 到最终 system prompt 的普通场景渲染

实施任务：

1. 新增 `PromptTemplateService`
2. 优先使用 Spring AI 的 `SystemPromptTemplate`
3. 若当前模块暂未接入 Spring AI，则先实现最小占位替换版本
4. 提供两个方法：
   - `render(String instructions, Map<String, Object> variables)`
   - `renderWithDocuments(String instructions, Map<String, Object> variables, String documents)`
5. 在 `renderWithDocuments(...)` 中强校验 `{documents}` 是否存在

输出结果：

- 普通场景下可稳定生成最终 system prompt
- 知识增强场景已有明确扩展口

### 第六阶段：最小执行器骨架

目标：

- 建立运行时接入点，但不一次性实现完整对话链

实施任务：

1. 新增 `BasicAgentExecutor`
2. 先实现以下最小能力：
   - 读取 `AgentContext.config.instructions`
   - 调用 `PromptVariableResolver`
   - 普通场景下调用 `PromptTemplateService.render(...)`
   - 知识增强场景下缓存 `context.promptVariables`，不提前渲染最终文档注入内容
3. 预留：
   - `buildMessages()`
   - `buildInstructions()`
   - 后续 `ChatModel` 调用

输出结果：

- 运行时 prompt 构建逻辑不再散落在 controller/service 中
- 后续可平滑对接知识检索、记忆、多轮会话

### 第七阶段：知识增强延迟渲染

目标：

- 补齐与文档对齐的 `{documents}` 延迟注入机制

实施任务：

1. 新增 `KnowledgePromptAugmentor`
2. 从 `AgentContext.promptVariables` 读取已解析变量
3. 合并 `{documents}`
4. 调用 `PromptTemplateService.renderWithDocuments(...)`
5. 缺失 `{documents}` 时抛出明确异常

输出结果：

- 与参考实现对齐
- 知识增强场景不会过早渲染 prompt

## 7. 具体改造文件清单

### 7.1 需要新增

- `agent-designer/src/main/java/com/nrec/service/basicagent/model/config/AgentConfig.java`
- `agent-designer/src/main/java/com/nrec/service/basicagent/model/request/AgentRequest.java`
- `agent-designer/src/main/java/com/nrec/service/basicagent/model/response/AgentResponse.java`
- `agent-designer/src/main/java/com/nrec/service/basicagent/model/runtime/AgentContext.java`
- `agent-designer/src/main/java/com/nrec/service/basicagent/model/chat/ChatMessage.java`
- `agent-designer/src/main/java/com/nrec/service/basicagent/model/chat/MessageRole.java`
- `agent-designer/src/main/java/com/nrec/service/basicagent/model/chat/ContentType.java`
- `agent-designer/src/main/java/com/nrec/service/basicagent/service/config/AgentConfigCodec.java`
- `agent-designer/src/main/java/com/nrec/service/basicagent/service/config/impl/AgentConfigCodecImpl.java`
- `agent-designer/src/main/java/com/nrec/service/basicagent/service/prompt/PromptVariableResolver.java`
- `agent-designer/src/main/java/com/nrec/service/basicagent/service/prompt/impl/PromptVariableResolverImpl.java`
- `agent-designer/src/main/java/com/nrec/service/basicagent/service/prompt/PromptTemplateService.java`
- `agent-designer/src/main/java/com/nrec/service/basicagent/service/prompt/impl/PromptTemplateServiceImpl.java`
- `agent-designer/src/main/java/com/nrec/service/basicagent/service/knowledge/KnowledgePromptAugmentor.java`
- `agent-designer/src/main/java/com/nrec/service/basicagent/service/knowledge/impl/KnowledgePromptAugmentorImpl.java`
- `agent-designer/src/main/java/com/nrec/service/basicagent/executor/BasicAgentExecutor.java`

### 7.2 需要修改

- `agent-designer/src/main/java/com/nrec/service/basicagent/service/app/impl/AgentAppVersionServiceImpl.java`
- 视实现方式选择性修改：
  - `agent-designer/pom.xml`
  - `agent-designer/src/test/java/...` 下现有版本服务、发布服务、快照服务测试

## 8. 接口与前端协同要求

现有版本保存接口保持不变：

- `/api/basic-agents/versions/update`

调用约定调整为：

- `config` 中显式传入 `instructions`
- `config` 中显式传入 `promptVariables`

建议示例：

```json
{
  "instructions": "你是一个数据分析助手。当前租户是 {tenant_name}。",
  "promptVariables": [
    {
      "name": "tenant_name",
      "type": "string",
      "description": "租户名称",
      "defaultValue": "默认租户"
    }
  ]
}
```

## 9. 测试计划

### 9.1 单元测试

- `AgentConfigCodecTest`
  - 正常 JSON 解析
  - 空配置处理
  - 序列化不丢字段
- `PromptVariableResolverTest`
  - 只读默认值
  - 请求覆盖已声明变量
  - 未声明变量被忽略
  - 空白值被过滤
- `PromptTemplateServiceTest`
  - 普通变量渲染
  - `{documents}` 注入
  - 缺失 `{documents}` 抛错

### 9.2 服务测试

- `AgentAppVersionServiceImplTest`
  - 保存带 `instructions/promptVariables` 的草稿配置
  - 非法变量声明保存失败
  - 发布后配置仍可取回
  - 切回草稿后配置不丢失

### 9.3 回归测试

- 创建应用后仍自动生成唯一草稿版本
- 已有发布流程不受影响
- 复制已发布应用时配置与知识绑定仍可恢复

## 10. 风险与处理

### 风险 1：模块命名和文档命名不一致

现象：

- 文档写 `basic-agent`
- 实际模块名是 `agent-designer`

处理：

- 一期全部以 `agent-designer` 为真实改造目标
- 代码包名保持现状，不做大规模重构

### 风险 2：Spring AI 依赖未接入

现象：

- `PromptTemplateService` 计划使用 `SystemPromptTemplate`

处理：

- 若模块依赖未满足，先做最小模板替换实现
- 二期再统一切到 Spring AI prompt template

### 风险 3：历史 config 兼容性

现象：

- 老版本 `config` 可能不含 `instructions/promptVariables`

处理：

- `AgentConfigCodec.parse(...)` 对缺失字段保持兼容
- 校验逻辑只约束新增字段的结构合法性，不强制老数据补齐

## 11. 里程碑定义

### M1：配置可保存

完成标准：

- `config` 可保存 `instructions`
- `config` 可保存 `promptVariables`
- 发布和切回草稿不丢内容

### M2：变量可解析

完成标准：

- 默认值可生效
- 请求可覆盖已声明变量
- 未声明变量无法注入
- 空值可过滤

### M3：提示词可渲染

完成标准：

- 普通场景可生成最终 system prompt
- 知识场景预留 `{documents}` 延迟渲染接口

### M4：执行器可接入

完成标准：

- 已形成独立 `BasicAgentExecutor` 骨架
- prompt 构建逻辑可从版本管理链路中独立出来

## 12. 推荐实施顺序

建议严格按以下顺序开发：

1. `AgentConfig`
2. `AgentConfigCodec`
3. `AgentAppVersionServiceImpl` 保存链路校验
4. 快照/版本切换回归测试
5. `AgentRequest / AgentContext`
6. `PromptVariableResolver`
7. `PromptTemplateService`
8. `BasicAgentExecutor`
9. `KnowledgePromptAugmentor`
10. 补齐单元测试与集成测试

## 13. 一期交付边界

一期必须完成：

- `instructions` 和 `promptVariables` 的配置保存
- 版本保存校验
- 发布快照兼容
- 草稿恢复兼容
- 变量解析
- 普通模板渲染

一期可以暂缓：

- 真实知识库检索接入
- 完整 `ChatModel` 执行
- Prompt 审计日志
- Tool calling
- 多轮记忆

## 14. 最终结论

本次改造不应直接重写当前版本管理体系，而应在现有 `agent-designer` 模块上做最小侵入增强：

- 保留 `config` 字符串存储方式
- 用 `AgentConfig` 接管配置解析和校验
- 用 `PromptVariableResolver` 与 `PromptTemplateService` 接管运行时 prompt 处理
- 用 `BasicAgentExecutor` 承接后续执行链扩展

这样改动面最小，且与前两份文档、当前模块结构、发布快照机制都能自然衔接。
