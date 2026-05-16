# data-agent-service 模型配置表结构设计

## 1. 目标

为 `BasicAgent` 的模型能力补齐平台化数据结构，支持：

- provider 管理
- model 管理
- 平台默认模型
- agent 级模型引用平台模型
- 后续参数规则扩展

同时兼容当前已有的 `model_config` 使用方式，避免一次性推翻旧链路。

---

## 2. 设计原则

### 2.1 分离 provider 和 model

不建议继续把所有信息都压在一张 `model_config` 表里。

原因：

- provider 凭证和 model 元数据语义不同
- 一个 provider 下天然会有多个 model
- 参数规则属于 model 维度，不属于 provider 维度
- 后续如果支持禁用 provider、替换 endpoint、批量切换模型，会更难维护

### 2.2 保留默认模型概念

当前系统已有“按类型取激活模型”的旧链路。

因此新表结构需要允许：

- 某类模型中存在默认模型
- 旧链路仍能快速查出默认 `CHAT` / `EMBEDDING`

### 2.3 支持运行时参数与规则分离

建议区分：

- 默认参数
- 支持参数规则
- 本次 agent 覆写参数

其中前两者属于平台持久化数据，第三者属于 `BasicAgent` 配置。

---

## 3. 推荐表结构

建议新增两张主表：

- `ai_model_provider`
- `ai_model`

可选保留：

- `model_config` 作为兼容表或视图来源

---

## 4. Provider 表设计

## 4.1 表名

`ai_model_provider`

## 4.2 字段设计

| 字段名 | 类型 | 说明 |
|---|---|---|
| `id` | bigint | 主键 |
| `provider_code` | varchar(64) | provider 业务编码，唯一 |
| `name` | varchar(128) | provider 名称 |
| `description` | varchar(512) | provider 描述 |
| `icon` | varchar(512) | 图标地址或标识 |
| `protocol` | varchar(64) | 协议类型，如 `openai` |
| `source` | varchar(64) | 来源，如 `system`、`custom` |
| `enabled` | tinyint | 是否启用 |
| `endpoint` | varchar(512) | provider 统一 endpoint |
| `api_key` | varchar(1024) | provider API Key |
| `extra_credential_json` | text | 扩展凭证 JSON |
| `created_time` | datetime | 创建时间 |
| `updated_time` | datetime | 更新时间 |
| `is_deleted` | tinyint | 逻辑删除 |

## 4.3 索引建议

- 主键：`id`
- 唯一索引：`uk_provider_code(provider_code)`
- 普通索引：`idx_enabled(enabled)`
- 普通索引：`idx_is_deleted(is_deleted)`

## 4.4 建表示例

```sql
CREATE TABLE ai_model_provider (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    provider_code VARCHAR(64) NOT NULL COMMENT 'provider业务编码',
    name VARCHAR(128) NOT NULL COMMENT 'provider名称',
    description VARCHAR(512) DEFAULT NULL COMMENT 'provider描述',
    icon VARCHAR(512) DEFAULT NULL COMMENT 'provider图标',
    protocol VARCHAR(64) NOT NULL DEFAULT 'openai' COMMENT '协议类型',
    source VARCHAR(64) DEFAULT NULL COMMENT '来源',
    enabled TINYINT NOT NULL DEFAULT 1 COMMENT '是否启用',
    endpoint VARCHAR(512) NOT NULL COMMENT 'API endpoint',
    api_key VARCHAR(1024) NOT NULL COMMENT 'API key',
    extra_credential_json TEXT DEFAULT NULL COMMENT '扩展凭证JSON',
    created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    is_deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    UNIQUE KEY uk_provider_code (provider_code),
    KEY idx_enabled (enabled),
    KEY idx_is_deleted (is_deleted)
) COMMENT='AI模型Provider表';
```

---

## 5. Model 表设计

## 5.1 表名

`ai_model`

## 5.2 字段设计

| 字段名 | 类型 | 说明 |
|---|---|---|
| `id` | bigint | 主键 |
| `provider_code` | varchar(64) | 所属 provider |
| `model_id` | varchar(128) | 模型真实调用 ID |
| `name` | varchar(128) | 模型展示名 |
| `model_type` | varchar(32) | 模型类型，如 `CHAT`、`EMBEDDING` |
| `mode` | varchar(32) | 模式，如 `chat` |
| `tags` | varchar(512) | 标签，逗号分隔或 JSON |
| `icon` | varchar(512) | 图标 |
| `enabled` | tinyint | 是否启用 |
| `is_default` | tinyint | 是否该类型默认模型 |
| `default_parameters_json` | text | 默认参数 JSON |
| `supported_parameters_json` | text | 参数规则 JSON |
| `created_time` | datetime | 创建时间 |
| `updated_time` | datetime | 更新时间 |
| `is_deleted` | tinyint | 逻辑删除 |

## 5.3 索引建议

- 主键：`id`
- 唯一索引：`uk_provider_model(provider_code, model_id)`
- 普通索引：`idx_model_type(model_type)`
- 普通索引：`idx_default(model_type, is_default)`
- 普通索引：`idx_enabled(enabled)`
- 普通索引：`idx_is_deleted(is_deleted)`

## 5.4 建表示例

```sql
CREATE TABLE ai_model (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    provider_code VARCHAR(64) NOT NULL COMMENT 'provider业务编码',
    model_id VARCHAR(128) NOT NULL COMMENT '模型真实调用ID',
    name VARCHAR(128) NOT NULL COMMENT '模型展示名称',
    model_type VARCHAR(32) NOT NULL COMMENT '模型类型',
    mode VARCHAR(32) DEFAULT 'chat' COMMENT '模式',
    tags VARCHAR(512) DEFAULT NULL COMMENT '标签',
    icon VARCHAR(512) DEFAULT NULL COMMENT '图标',
    enabled TINYINT NOT NULL DEFAULT 1 COMMENT '是否启用',
    is_default TINYINT NOT NULL DEFAULT 0 COMMENT '是否默认模型',
    default_parameters_json TEXT DEFAULT NULL COMMENT '默认参数JSON',
    supported_parameters_json TEXT DEFAULT NULL COMMENT '支持参数规则JSON',
    created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    is_deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    UNIQUE KEY uk_provider_model (provider_code, model_id),
    KEY idx_model_type (model_type),
    KEY idx_default (model_type, is_default),
    KEY idx_enabled (enabled),
    KEY idx_is_deleted (is_deleted)
) COMMENT='AI模型表';
```

---

## 6. 外键与约束建议

如果当前数据库规范允许外键，可加：

```sql
ALTER TABLE ai_model
ADD CONSTRAINT fk_ai_model_provider
FOREIGN KEY (provider_code) REFERENCES ai_model_provider(provider_code);
```

如果项目不希望使用物理外键，则在业务层保证：

- 新增模型前必须校验 provider 存在
- 删除 provider 前必须校验该 provider 下无有效模型

---

## 7. 默认模型实现方案

当前旧链路按 `ModelType` 查询“激活模型”。

新结构下建议用：

- `model_type`
- `enabled`
- `is_default`

作为默认模型判断条件。

例如：

- 默认聊天模型：
  - `model_type='CHAT'`
  - `enabled=1`
  - `is_default=1`
  - `is_deleted=0`

查询示例：

```sql
SELECT *
FROM ai_model
WHERE model_type = 'CHAT'
  AND enabled = 1
  AND is_default = 1
  AND is_deleted = 0
LIMIT 1;
```

说明：

- 业务层需保证同一 `model_type` 最多一条默认记录
- 切换默认模型时，建议事务内先清旧默认，再设新默认

---

## 8. 参数字段存储方案

## 8.1 `default_parameters_json`

用途：

- 存平台默认参数

示例：

```json
{
  "temperature": 0.3,
  "maxTokens": 8192,
  "topP": 0.8,
  "repetitionPenalty": 1.1,
  "thinking": false
}
```

## 8.2 `supported_parameters_json`

用途：

- 存参数规则定义，供前端动态渲染

示例：

```json
[
  {
    "key": "temperature",
    "label": "温度",
    "valueType": "number",
    "required": false,
    "defaultValue": 0.3,
    "minValue": 0,
    "maxValue": 2,
    "enabled": true
  },
  {
    "key": "thinking",
    "label": "思考模式",
    "valueType": "boolean",
    "required": false,
    "defaultValue": false,
    "enabled": true
  }
]
```

---

## 9. 与现有 `model_config` 表的关系

当前系统已有：

- `model_config`

且旧代码依赖：

- `ModelConfigMapper.selectActiveByType(...)`
- `ModelConfigDataService`
- `AiModelRegistry`

因此建议分阶段迁移。

## 9.1 方案 A：兼容期并行

短期内：

- 保留 `model_config`
- 新增 `ai_model_provider`
- 新增 `ai_model`

使用策略：

- 新管理层写入新表
- 旧链路仍读 `model_config`
- 迁移完成后再将旧链路改为读新表

优点：

- 风险低

缺点：

- 有双写或同步成本

## 9.2 方案 B：新表落地后改旧读链路

短期内先不双写。

实施顺序：

1. 建新表
2. 管理层改写新表
3. 修改 `ModelConfigDataService`，改为从 `ai_model + ai_model_provider` 聚合读取默认模型
4. 最后废弃 `model_config`

优点：

- 结构干净

缺点：

- 需要一次性改旧链路读取逻辑

## 9.3 当前推荐

推荐 `方案 B`，但要分步骤执行：

1. 先建新表
2. 先写新管理链路
3. 再把 `ModelConfigDataService` 切到新表
4. `model_config` 进入兼容/废弃阶段

---

## 10. `ModelConfigDataService` 新读法建议

改造后，平台默认模型读取建议从新表聚合：

### 10.1 查询逻辑

1. 查 `ai_model` 默认模型
2. 查关联 `ai_model_provider`
3. 聚合成 `ModelConfigDTO`

### 10.2 聚合结果字段来源

- `provider` <- `ai_model_provider.provider_code`
- `baseUrl` <- `ai_model_provider.endpoint`
- `apiKey` <- `ai_model_provider.api_key`
- `modelName` <- `ai_model.model_id`
- `defaultParameters` <- `ai_model.default_parameters_json`

### 10.3 参数映射

从 `default_parameters_json` 中解析：

- `temperature`
- `maxTokens`
- `topP`
- `repetitionPenalty`
- `thinking`

---

## 11. 支持的查询场景

新表结构要覆盖以下查询：

### 11.1 provider 列表

按名称模糊查询 provider。

### 11.2 provider 详情

按 `provider_code` 查询 provider 凭证与元数据。

### 11.3 provider 下模型列表

按 `provider_code` 查全部模型。

### 11.4 模型详情

按 `provider_code + model_id` 查模型详情。

### 11.5 默认模型查询

按 `model_type` 查默认模型。

### 11.6 已启用模型查询

按 `enabled=1` 查模型。

### 11.7 模型选择器查询

按 `model_type` 查询启用 provider 下的启用模型，并按 provider 分组。

---

## 12. 迁移步骤建议

### 第一步

- 新建 `ai_model_provider`
- 新建 `ai_model`

### 第二步

- 实现 `ProviderMapper`
- 实现 `ModelMapper`
- 实现 `ProviderManager`
- 实现 `ModelManager`

### 第三步

- 实现 `ProviderController`
- 实现 `ModelController`

### 第四步

- 修改 `ModelConfigDataService`
- 改为从新表读取默认模型

### 第五步

- 保留 `model_config` 兼容一段时间
- 确认新链路稳定后废弃旧表或停止使用

---

## 13. 未来扩展预留

当前表结构已为以下能力预留空间：

- 多 provider
- 多 model type
- provider 启停
- model 启停
- 默认模型切换
- 参数规则动态渲染
- OpenAI-compatible 多 endpoint

后续可扩展：

- `RERANK` 模型类型
- `VISION` 模型类型
- provider 私有参数规则
- provider 代理设置
- workspace / tenant 隔离

---

## 14. 总结

推荐最终结构是：

- `ai_model_provider` 管 provider
- `ai_model` 管模型

`BasicAgent` 运行时不直接依赖表，而是通过：

- `ProviderManager`
- `ModelManager`
- `AgentModelFacade`

获取模型配置。

旧的 `AiModelRegistry` 和 `ModelConfigDataService` 继续保留，但底层数据来源逐步迁移到新表结构。
