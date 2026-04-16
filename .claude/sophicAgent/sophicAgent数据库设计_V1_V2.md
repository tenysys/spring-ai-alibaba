# SophicAgent 数据库设计

## 1. 设计原则

- 主键规范：统一使用 `id bigint unsigned auto_increment`，业务主键使用 `xxx_id` / `xxx_code`。
- 状态规范：统一使用 `status`；需要开关控制时补充 `enabled`。
- 时间规范：统一使用 `gmt_create`、`gmt_modified`；运行态补充 `gmt_start`、`gmt_end`。
- 时间字段说明：`gmt_*` 仅作为统一时间字段命名规范，不强制表示 GMT/UTC 时区，实际时区以系统存储与应用约定为准。
- 扩展字段：复杂配置优先使用 `json` 或 `text/longtext`，承载快照、策略、DSL、扩展元数据。
- 账号权限域：沿用现有权限与认证服务的既有模型和数据表，SophicAgent 只做业务关联，不改造该域设计。
- 应用与设计器域：参考 `spring-ai-alibaba-admin` 的 `application`、`application_version`、`application_component`、`agent_schema` 设计。
- 工作流设计：V1 不优先拆 `workflow_definition / workflow_version / workflow_node / workflow_edge` 独立结构表，完整流程配置优先存放于 `sophic_agent_application_version.config_snapshot`。
- MCP、知识库：字段设计优先参考 admin 项目现有 `mcp_server`、`knowledge_base`、`document` 表的设计方式。

## 2. V1 全量表清单

### 2.1 账号权限域

- `users`（已有）
- `user_info`（已有）
- `user_additional_info`（已有）
- `user_login`（已有）
- `user_sign`（已有）
- `priv_group`（已有）
- `priv_role`（已有）
- `priv_permission`（已有）
- `priv_menu_resource`（已有）
- `priv_menu_access`（已有）
- `priv_group_role_relation`（已有）
- `priv_role_permission_relation`（已有）
- `priv_user_group_relation`（已有）
- `sophic_agent_api_key`
- `sophic_agent_resource`
- `sophic_agent_resource_acl`

### 2.2 应用与设计器域

- `sophic_agent_agent_template`
- `sophic_agent_application`
- `sophic_agent_application_version`
- `sophic_agent_agent_schema`
- `sophic_agent_application_binding`
- `sophic_agent_application_binding_item`
- `sophic_agent_high_code_service`
- `sophic_agent_high_code_service_version`
- `sophic_agent_guardrail_rule`
- `sophic_agent_guardrail_fixed_reply`

### 2.3 运行时域

- `sophic_agent_session`
- `sophic_agent_session_message`
- `sophic_agent_task`
- `sophic_agent_execution_step`
- `smc_application`（已有）
- `smc_service`（已有）
- `smc_instance`（已有）

### 2.4 能力资产域

- `sophic_agent_knowledge_base`
- `sophic_agent_knowledge_document`
- `sophic_agent_knowledge_chunk`
- `sophic_agent_tool`
- `sophic_agent_tool_version`
- `sophic_agent_tool_debug_record`
- `sophic_agent_mcp_server`
- `sophic_agent_mcp_server_instance`
- `sophic_agent_memory_short_term`
- `sophic_agent_memory_library`
- `sophic_agent_memory_rule`
- `sophic_agent_memory_long_term`
- `sophic_agent_memory_hit_record`
- `sophic_agent_memory_entity`
- `sophic_agent_memory_recall_test`
- `sophic_agent_datasource`
- `sophic_agent_datasource_table`
- `sophic_agent_datasource_field`
- `sophic_agent_datasource_relation`
- `sophic_agent_datasource_semantic_model`

### 2.5 治理观测与运营域

- `sophic_agent_model_provider`
- `sophic_agent_model`
- `sophic_agent_model_config`
- `sophic_agent_invoke_log`
- `sophic_agent_runtime_metric`
- `sophic_agent_agent_feedback`
- `sophic_agent_publish_record`
- `sophic_agent_eval_dataset`
- `sophic_agent_eval_dataset_item`
- `sophic_agent_eval_task`
- `sophic_agent_eval_result`
- `sophic_agent_perf_test_task`

## 3. 表设计

### 3.1 账号权限域

该域继续依赖现有权限与认证服务，不复用当前代码中的另一套账号模型。

- `users`（已有）
  - 用户信息表。
  - 关键字段：`ID`、`NAME`、`PASSWORD`、`ENABLED`、`TYPE`、`SALT`
- `user_info`（已有）
  - 用户个人信息表。
  - 关键字段：`USER_ID`、`PHONE`、`E_MAIL`、`POSITION`、`DESCRIPTION`、`ORG_ID`、`ORDERNUM`、`CREATE_TIME`、`PWD_CHANGE_TIME`
- `user_additional_info`（已有）
  - 用户额外信息表。
  - 关键字段：`user_id`、`person_name`、`aornum`、`nationality`、`sex`、`card_type`、`id_card`、`create_time`、`major`、`annex`、`avatar`、`additional_info`、`source`
- `user_login`（已有）
  - 用户登录信息表。
  - 关键字段：`USER_ID`、`TOKEN`、`USER_ROLE`、`SERVER_NAME`、`CLIENT_IP`、`CLIENT_BROWSER`、`LOGIN_STATUS`、`LOGIN_TIME`、`LOGOUT_TIME`、`LOGIN_ERR_TIMES`、`LOGIN_ERR_MSG`、`ONLINE_TIME`
- `user_sign`（已有）
  - 用户密码签名信息表。
  - 关键字段：`user_id`、`digest`、`last_modified_time`
- `priv_group`（已有）
  - 用户组表。
  - 关键字段：`id`、`name`、`type`、`create_time`、`update_time`、`enable`、`description`
- `priv_role`（已有）
  - 角色表。
  - 关键字段：`id`、`name`、`update_time`、`description`、`is_default`、`type`、`fid`
- `priv_permission`（已有）
  - 权限表。
  - 关键字段：`id`、`service_id`、`name`、`permission`、`description`、`type`、`is_default`
- `priv_menu_resource`（已有）
  - 菜单表，用于定义系统菜单、页面入口和菜单树结构。
  - 关键字段：`id`、`service_id`、`type`、`seq`、`name`、`route`、`icon`、`params`、`description`、`fid`
- `priv_menu_access`（已有）
  - 菜单类权限关联表，用于建立权限点与菜单/菜单元素之间的映射关系。
  - 关键字段：`per_id`、`menu_id`、`ele_id`
- `priv_group_role_relation`（已有）
  - 组角色关联表。
  - 关键字段：`group_id`、`role_id`
- `priv_role_permission_relation`（已有）
  - 角色权限关联表。
  - 关键字段：`role_id`、`permission_id`
- `priv_user_group_relation`（已有）
  - 用户组关联表。
  - 关键字段：`user_id`、`group_id`
- `sophic_agent_api_key`
  - SophicAgent 侧 API 调用凭证表。
  - 关键字段：`group_id`、`user_id`、`api_key`、`description`、`expired_at`、`status`
- `sophic_agent_resource`
  - 统一资源注册表，用于权限控制时对应用、工具、知识库、数据源、MCP 服务等资源进行统一标识和授权关联。
- 关键字段：`id`、`resource_id`、`resource_name`、`resource_type`、`creator_id`、`create_time`、`update_time`、`owner_user_id`、`ext_config`、`status`
- `sophic_agent_resource_acl`
  - 资源访问控制表，用于实现具体业务资源的读写权限分离，授权粒度支持个人、组、研究所。
  - 关键字段：`resource_id`、`subject_type`、`subject_id`、`permission_type`、`grant_type`、`status`、`creator`、`modifier`

说明：

- `priv_menu_resource` 和 `priv_menu_access` 负责菜单、页面入口、按钮元素等前台可见功能项的控制。
- `priv_permission`、`priv_role_permission_relation` 负责功能权限点控制。
- `sophic_agent_resource` 与后续资源 ACL 负责具体业务资源的读写权限控制。
- 三者职责边界如下：
  - 菜单权限：控制“能否看到什么页面/菜单/按钮”
  - 功能权限：控制“能否调用什么功能接口”
  - 资源权限：控制“能否读写哪个具体业务对象”

#### 权限控制流程

- SophicAgent 权限控制分为三层：
  - 菜单权限
  - 功能权限
  - 资源权限

#### 菜单权限

- 由 `priv_menu_resource` 与 `priv_menu_access` 承载。
- 用于控制：
  - 能否看到某个菜单
  - 能否进入某个页面
  - 能否看到某个按钮或菜单元素
- 判定方式
  - 用户通过 `priv_user_group_relation` 找到所属组
  - 用户组通过 `priv_group_role_relation` 找到所属角色
  - 角色通过 `priv_role_permission_relation` 找到权限点
  - 权限点通过 `priv_menu_access` 关联到菜单和元素

#### 功能权限

- 由 `priv_permission`、`priv_group_role_relation`、`priv_role_permission_relation` 承载。
- 用于控制：
  - 能否访问某类系统功能
  - 能否调用某类接口
  - 能否进入设计器、能力中心、治理中心等模块
- 判定方式
  - 先基于用户所属组和角色计算权限点
  - 再根据权限编码判断功能访问权

#### 资源权限

- 由 `sophic_agent_resource` 与 `sophic_agent_resource_acl` 承载。
- 用于控制：
  - 能否读取某个具体业务对象
  - 能否修改某个具体业务对象
- 资源对象包括：
  - 智能体应用
  - 高代码服务
  - 工具
  - MCP 服务
  - 知识库
  - 数据源
  - 记忆库
- 判定方式
  - 先定位业务对象对应的 `resource_id`
  - 再根据 `resource_acl` 判断当前主体是否具备 `READ/WRITE`
  - 主体粒度支持：
    - `USER`
    - `GROUP`
    - `INSTITUTE`

#### 统一鉴权流程

1. 用户登录后，先通过现有账号权限域完成身份认证。
2. 根据用户所属组、角色和权限点判断菜单与功能权限。
3. 当访问具体资源时，定位到 `sophic_agent_resource.resource_id`。
4. 读取 `sophic_agent_resource_acl`，判断当前用户、所属组或所属研究所是否拥有对应 `READ/WRITE` 权限。
5. 功能权限通过后且资源权限命中后，才允许执行具体业务操作。

#### 读写权限约定

- `READ`
  - 查看详情
  - 查询列表
  - 运行时使用
- `WRITE`
  - 编辑
  - 删除
  - 发布
  - 权限设置
  - 绑定组件
- 约定建议
  - `WRITE` 默认包含 `READ`

#### 默认授权建议

- 新建资源时，建议同步在 `sophic_agent_resource` 中注册资源。
- 同时写入默认 ACL：
  - 创建人 `USER + WRITE`
  - 所属研究所 `INSTITUTE + READ`
  - 如有管理员组，可追加 `GROUP + WRITE`

### 3.2 应用与设计器域

- `sophic_agent_agent_template`
  - 平台通用智能体模板表，用于新建智能体时提供初始化蓝本，不承载发布后的智能体实例。
  - 关键字段：`template_id`、`template_code`、`template_name`、`template_type`、`scene_type`、`description`、`agent_type`、`schema_snapshot`、`config_snapshot`、`input_schema`、`output_schema`、`icon`、`tags`、`sort_no`、`enabled`、`status`
- `sophic_agent_application`
  - 应用主表，参考 admin 的 `application` 表，统一承载通用智能体、专用智能体、工作流型应用。
  - 关键字段：`agent_id`、`agent_code`、`name`、`description`、`icon`、`source`、`type`、`agent_scope`、`scene_type`、`latest_version`、`published_version`、`tags`、`status`、`creator`、`modifier`
- `sophic_agent_application_version`
  - 应用版本表，参考 admin 的 `application_version` 表。
  - 关键字段：`agent_id`、`version`、`version_desc`、`config_snapshot`、`runtime_config`、`input_schema`、`output_schema`、`dsl_schema`、`change_log`、`base_version`、`status`、`creator`、`modifier`
- `sophic_agent_agent_schema`
  - Agent 特有结构化定义表，参考 admin 的 `agent_schema` 表，仅在 `type=agent` 时使用。
  - 关键字段：`agent_schema_id`、`agent_id`、`version`、`name`、`description`、`agent_type`、`instruction`、`input_keys`、`output_key`、`handle_config`、`sub_agents`、`yaml_schema`、`enabled`、`status`
- `sophic_agent_application_binding`
  - 应用挂载组件表，对标 admin 的 `application_component`，用于承载“应用上挂了什么组件”。
  - 关键字段：`binding_id`、`agent_id`、`agent_version`、`resource_type`、`resource_id`、`resource_name`、`binding_source`、`sort_no`、`enabled`、`binding_config`、`status`
- `sophic_agent_application_binding_item`
  - 挂载组件详细信息表，对应 admin `reference` 的细粒度语义。
  - 关键字段：`binding_id`、`item_type`、`item_id`、`item_name`、`item_path`、`item_config`、`sort_no`、`status`
- `sophic_agent_high_code_service`
  - 高代码服务注册主表，用于从运行服务中筛选、登记高代码服务，并作为版本管理入口。
- 关键字段：`service_id`、`service_code`、`name`、`service_type`、`runtime_type`、`owner_user_id`、`latest_version`、`status`
- `sophic_agent_high_code_service_version`
  - 高代码服务版本表，用于管理高代码服务不同版本的制品与部署配置。
  - 关键字段：`service_id`、`version`、`package_type`、`package_uri`、`deploy_config`、`input_schema`、`output_schema`、`change_log`、`status`
- `sophic_agent_guardrail_rule`
  - 应用规则干预配置表，用于对输入和输出内容执行正则匹配、替换、屏蔽等规则干预。
  - 关键字段：`agent_id`、`rule_id`、`rule_code`、`rule_type`、`scope_type`、`scope_code`、`match_config`、`action_config`、`priority`、`enabled`、`status`
- `sophic_agent_guardrail_fixed_reply`
  - 应用固定问题输出配置表，用于对固定问题或相似问题配置预设回答内容。
  - 关键字段：`agent_id`、`record_id`、`rule_id`、`task_id`、`session_id`、`input_snapshot`、`output_snapshot`、`action_result`、`gmt_create`

说明：

- `sophic_agent_agent_template` 用于平台提供的通用智能体模板，不用于承载发布后的智能体。
- `sophic_agent_application_binding` 用于承载挂载组件。
- `sophic_agent_application_binding_item` 用于承载挂载组件的详细信息。
- `type=workflow` 时，完整工作流 DSL、节点、边、画布和调试配置统一进入 `config_snapshot`。
- `sophic_agent_high_code_service.service_id` 建议直接复用 `smc_service.id`，用于和运行态服务建立稳定映射。
- `sophic_agent_high_code_service.service_code` 作为业务侧服务编码，用于展示、检索、发布和权限控制，不要求等于 `smc_service.id`。
- `sophic_agent_guardrail_rule` 属于应用配置的一部分，一个应用可以配置多条护栏规则。
- `sophic_agent_guardrail_rule` 负责输入/输出规则干预，典型能力为正则匹配与替换。
- `sophic_agent_guardrail_fixed_reply` 负责固定问题输出配置，属于应用数据干预能力的一部分。

#### 智能体模板与复制边界

- `sophic_agent_agent_template`
  - 用于平台提供的通用智能体模板。
  - 用于“新建智能体”时提供初始化蓝本。
  - 不承载已发布智能体实例。
- 智能体复制
  - 不通过模板表实现。
  - 属于应用复制能力。
  - 目标是把一个已发布智能体复制为新的草稿智能体，供二次编辑。

#### 智能体复制机制

- 复制来源
  - `sophic_agent_application`
  - `sophic_agent_application_version`
  - `sophic_agent_agent_schema`
  - `sophic_agent_application_binding`
  - `sophic_agent_application_binding_item`
- 复制规则
  - 生成新的 `agent_id`、`agent_code`
  - 复制应用基础信息，但状态初始化为草稿
  - 复制指定来源版本为新应用的初始版本
  - 复制对应的 `agent_schema`
  - 复制挂载组件及其详细信息
  - 不复用原应用的发布记录、评测记录、运行记录、反馈记录
- 复制结果
  - 形成一个新的 `sophic_agent_application`
  - 形成一个新的初始 `sophic_agent_application_version`
  - 形成与之对应的一套 `agent_schema`、`binding`、`binding_item`

#### 发布机制

- 发布分为两类：
  - 发布为应用
  - 发布为工具

#### 发布为应用

- 适用对象
  - 智能体应用
  - 工作流应用
- 落库方式
  - 更新 `sophic_agent_application.published_version`
  - 更新 `sophic_agent_application.status`
  - 写入 `sophic_agent_publish_record`
- 发布记录内容
  - 发布对象类型 `asset_type=APPLICATION`
  - 发布对象 `asset_id`
  - 发布版本 `asset_version`
  - 输入输出定义
  - 配置快照
  - 变更摘要
- 发布结果
  - 应用在智能体管理界面可见
  - 可在运行中心直接使用
  - 可查询版本详情、导出 DSL、进行反馈

#### 发布为工具

- 适用对象
  - 智能体应用
  - 工作流应用
  - 高代码服务
- 落库方式
  - 写入 `sophic_agent_publish_record`
  - 在 `sophic_agent_resource` 中注册或更新统一资源
  - 如需在工具中心独立管理，可在 `sophic_agent_tool` / `sophic_agent_tool_version` 中生成对应工具定义
- 发布记录内容
  - 发布对象类型 `asset_type=APPLICATION/HIGH_CODE_SERVICE`
  - 发布类型 `publish_type=TOOL`
  - 目标资源 `target_resource_id`
  - 输入输出定义
  - 配置快照
  - 变更摘要
- 发布结果
  - 进入能力组件系统
  - 可作为其他智能体的工具进行绑定和使用
  - 可由工具中心继续启用、禁用、删除和授权

#### 发布补充说明

- 发布记录统一由 `sophic_agent_publish_record` 承载。
- 发布不改变历史版本内容，发布动作只改变“哪个版本被正式使用”。
- 发布为工具时，建议以 `sophic_agent_resource` 作为统一资源锚点，以便后续权限控制和复用管理。

### 3.3 运行时域

- `sophic_agent_session`
  - 会话主表，用于承载会话级状态。
- 关键字段：`session_id`、`agent_id`、`agent_version`、`user_id`、`session_title`、`source_type`、`gmt_last_active`、`status`
- `sophic_agent_session_message`
  - 会话消息表。
  - 关键字段：`session_id`、`message_id`、`seq_no`、`role`、`content`、`content_type`、`token_usage`、`metadata`、`gmt_create`
- `sophic_agent_task`
  - 单次执行主表，用于承载“一条用户消息触发的一次智能体/工作流执行”。
  - 关键字段：`task_id`、`session_id`、`trigger_message_id`、`response_message_id`、`agent_id`、`agent_version`、`task_type`、`task_name`、`input_payload`、`output_payload`、`final_result`、`progress`、`error_code`、`error_message`、`gmt_start`、`gmt_end`、`status`
- `sophic_agent_execution_step`
  - 执行步骤明细表，用于逐步记录“执行步骤是什么、做了什么、结果是什么”。
  - 关键字段：`task_id`、`step_no`、`step_id`、`step_type`、`step_name`、`step_desc`、`executor_type`、`tool_ref`、`input_snapshot`、`output_snapshot`、`thought_snapshot`、`cost_ms`、`error_code`、`error_message`、`status`
- `smc_application`（已有）
  - 高代码运行应用表，用于管理运行平台中的应用归属信息。
  - 关键字段：`application_id`、`application_name`、`owner`、`create_time`、`note`、`seq`
- `smc_service`（已有）
  - Nacos 通用服务表，用于承载从 Nacos 获取的服务定义信息，不只包含高代码服务。
  - 关键字段：`id`、`service_name`、`source`、`params`、`type`、`create_time`、`update_time`、`note`、`version`、`service_info`、`ref_application`、`seq`
- `smc_instance`（已有）
  - 高代码服务实例表，用于管理服务实例运行状态、地址与启停可用性。
  - 关键字段：`instance_id`、`service_id`、`ip`、`port`、`type`、`instance_mode`、`fingerprint`、`enabled`、`update_time`、`insert_time`、`version`、`last_offline_time`、`weight`

说明：

- 一次 `sophic_agent_session_message(role=USER)` 通常触发一次 `sophic_agent_task`。
- 一次 `sophic_agent_task` 对应本轮对话的一次完整执行，最终可产出一条 `response_message_id` 对应的回复消息。
- 一次 `sophic_agent_task` 下可以存在多个 `sophic_agent_execution_step`，用于完整还原本轮执行轨迹。
- `sophic_agent_execution_step` 负责按步骤留痕，记录每一步执行动作、输入、输出和结果。
- `smc_application`、`smc_service`、`smc_instance` 为已有运行管理表，继续复用，不在 SophicAgent 内重复设计高代码服务启停模型。
- `smc_service` 为从 Nacos 获取的通用服务表，`smc_instance` 为对应实例表，二者不只服务于高代码场景。
- SophicAgent 通过 `sophic_agent_high_code_service` 对 `smc_service` 中的服务进行筛选、登记和新增，只将被纳入管理范围的服务视为高代码服务。
- 已存在于 `smc_service` 的服务，可通过筛选后纳入 `sophic_agent_high_code_service` 管理，纳管后保持 `sophic_agent_high_code_service.service_id = smc_service.id`。
- 新增高代码服务时，先在 `sophic_agent_high_code_service` 中登记，再同步写入或发布到 `smc_service`，并保持两侧 `service_id` 一致。
- `sophic_agent_high_code_service` / `sophic_agent_high_code_service_version` 用于高代码服务注册和版本管理。
- `smc_service` / `smc_instance` 用于通用服务运行控制、实例发现和启停管理，`smc_application` 用于运行平台中的应用归属管理。
- V1 任务执行状态统一由 `sophic_agent_task` 承载，不单独设计任务调度队列表。
- 如后续确实存在独立调度中心、多节点抢占、延迟任务、重试编排等需求，再补充独立队列表或调度事件表。

### 3.4 能力资产域

#### 3.4.1 知识资产

- `sophic_agent_knowledge_base`
  - 知识库主表，参考 admin 的 `knowledge_base` 表。
  - 关键字段：`kb_id`、`type`、`status`、`name`、`description`、`process_config`、`index_config`、`search_config`、`total_docs`、`creator`、`modifier`
- `sophic_agent_knowledge_document`
  - 知识文档表，参考 admin 的 `document` 表。
  - 关键字段：`kb_id`、`doc_id`、`type`、`status`、`enabled`、`name`、`format`、`size`、`metadata`、`index_status`、`path`、`parsed_path`、`process_config`、`source`、`error`、`creator`、`modifier`
- `sophic_agent_knowledge_chunk`
  - 知识分片表。
  - 关键字段：`kb_id`、`doc_id`、`chunk_id`、`content`、`metadata`、`vector_id`、`status`

#### 3.4.2 工具与 MCP 资产

- `sophic_agent_tool`
  - 工具主表。
  - 关键字段：`tool_id`、`tool_code`、`name`、`description`、`tool_type`、`source`、`source_asset_type`、`source_asset_id`、`source_asset_version`、`publish_id`、`api_schema`、`config`、`test_status`、`enabled`、`latest_version`、`status`、`creator`、`modifier`
- `sophic_agent_tool_version`
  - 工具版本表。
  - 关键字段：`tool_id`、`version`、`version_desc`、`schema_snapshot`、`config_snapshot`、`status`
- `sophic_agent_tool_debug_record`
  - 工具调试记录。
  - 关键字段：`tool_id`、`request_payload`、`response_payload`、`success`、`error_message`、`cost_ms`
- `sophic_agent_mcp_server`
  - MCP 服务主表，参考 admin 的 `mcp_server` 表。
  - 关键字段：`server_code`、`name`、`description`、`source`、`deploy_env`、`type`、`deploy_config`、`user_id`、`status`、`biz_type`、`detail_config`、`host`、`install_type`、`creator`、`modifier`
- `sophic_agent_mcp_server_instance`
  - MCP 服务实例表，支撑服务实例列表、健康状态、运行控制。
  - 关键字段：`instance_id`、`server_code`、`instance_name`、`endpoint`、`health_status`、`runtime_status`、`gmt_last_heartbeat`、`metadata`

#### 3.4.3 记忆资产

- `sophic_agent_memory_short_term`
  - 短期记忆表。
  - 关键字段：`session_id`、`seq_no`、`role`、`content`、`metadata`、`expired_at`
- `sophic_agent_memory_library`
  - 记忆库主表。
- 关键字段：`memory_library_id`、`library_code`、`name`、`description`、`owner_user_id`、`default_rule_id`、`permission_scope`、`status`
- `sophic_agent_memory_rule`
  - 记忆规则表。
  - 关键字段：`rule_id`、`memory_library_id`、`rule_name`、`extract_mode`、`expire_days`、`rule_content`、`status`
- `sophic_agent_memory_long_term`
  - 长期记忆明细表。
  - 关键字段：`memory_library_id`、`agent_id`、`user_id`、`memory_id`、`entity_id`、`session_id`、`content`、`summary_content`、`memory_type`、`tags`、`rule_snapshot`、`metadata`、`embedding_ref`、`score`、`expired_at`、`hit_count`、`last_hit_time`、`status`
- `sophic_agent_memory_hit_record`
  - 记忆命中记录表。
  - 关键字段：`hit_id`、`memory_library_id`、`memory_id`、`task_id`、`query_text`、`similarity_score`、`status`
- `sophic_agent_memory_entity`
  - 应用记忆归档表，用于记录某个应用（智能体或工作流）所属的记忆归档对象。
  - 关键字段：`entity_id`、`memory_library_id`、`agent_id`、`entity_type`、`entity_name`、`entity_summary`、`metadata`、`status`
- `sophic_agent_memory_recall_test`
  - 记忆召回测试表。
  - 关键字段：`test_id`、`memory_library_id`、`query_text`、`expected_memory_id`、`actual_result`、`score_detail`、`status`

说明：

- `sophic_agent_memory_long_term`、`sophic_agent_memory_entity`、`sophic_agent_memory_hit_record` 构成记忆主链路。
- `sophic_agent_memory_recall_test` 用于记忆检索测试和命中率验证，保留为测试支撑表。
- 记忆抽取过程不再单独设计 `sophic_agent_memory_extract_log`，如需排查抽取过程，优先复用运行日志、任务步骤日志或通用调试日志。

#### 3.4.4 数据源与语义资产

- `sophic_agent_datasource`
  - 数据源主表。
  - 关键字段：`datasource_id`、`datasource_code`、`datasource_name`、`schema_type`、`datasource_type`、`host`、`port`、`database_name`、`username`、`password_cipher`、`connection_url`、`connect_config`、`gmt_last_sync`、`status`
- `sophic_agent_datasource_table`
  - 数据源表元数据。
  - 关键字段：`datasource_id`、`table_id`、`schema_name`、`table_name`、`table_comment`、`refresh_version`、`is_deleted`、`status`
- `sophic_agent_datasource_field`
  - 数据源字段元数据。
  - 关键字段：`datasource_id`、`table_id`、`field_id`、`column_name`、`column_comment`、`data_type`、`is_primary`、`is_foreign`、`is_not_null`、`field_status`、`refresh_version`、`is_deleted`、`status`
- `sophic_agent_datasource_relation`
  - 数据源逻辑关系表。
  - 关键字段：`relation_id`、`datasource_id`、`source_table_id`、`target_table_id`、`source_field_name`、`target_field_name`、`relation_type`、`description`、`status`
- `sophic_agent_datasource_semantic_model`
  - 数据源语义配置表。
  - 关键字段：`semantic_id`、`datasource_id`、`table_id`、`field_id`、`semantic_level`、`model_name`、`field_name`、`business_name`、`synonyms`、`business_description`、`metadata`、`status`

### 3.5 治理观测与运营域

- `sophic_agent_model_provider`
  - 模型供应商表，参考 admin 项目的 `provider` 表设计。
  - 关键字段：`provider_code`、`provider_key`、`name`、`icon`、`description`、`protocol`、`credential`、`supported_model_types`、`source`、`enabled`、`status`
- `sophic_agent_model`
  - 模型定义表，参考 admin 项目的 `model` 表设计。
  - 关键字段：`model_code`、`provider_code`、`model_id`、`name`、`icon`、`model_type`、`mode`、`tags`、`source`、`enabled`、`status`
- `sophic_agent_model_config`
  - 模型接入配置表，参考 admin 项目的 `model_config` 表设计，用于承载模型服务地址、API Key 和默认参数配置。
  - 关键字段：`config_id`、`config_name`、`provider_code`、`model_code`、`base_url`、`api_key_cipher`、`default_parameters`、`supported_parameters`、`enabled`、`status`
- `sophic_agent_invoke_log`
  - 调用日志。
  - 关键字段：`trace_id`、`request_id`、`task_id`、`agent_id`、`invoke_type`、`target_code`、`input_digest`、`output_digest`、`error_code`、`error_message`、`cost_ms`、`status`
- `sophic_agent_runtime_metric`
  - 运行指标。
  - 关键字段：`metric_scope`、`metric_name`、`metric_value`、`metric_tags`、`collect_time`
- `sophic_agent_agent_feedback`
  - 反馈表。
- 关键字段：`agent_id`、`task_id`、`session_id`、`user_id`、`rating`、`feedback_type`、`content`、`status`
- `sophic_agent_publish_record`
  - 发布记录表。
  - 关键字段：`publish_id`、`asset_type`、`asset_id`、`asset_version`、`publish_type`、`target_resource_id`、`input_schema`、`output_schema`、`config_snapshot`、`change_log`、`operator_id`、`status`
- `sophic_agent_eval_dataset`
  - 评测集主表。
- 关键字段：`dataset_id`、`dataset_name`、`dataset_type`、`description`、`owner_user_id`、`status`
- `sophic_agent_eval_dataset_item`
  - 评测集样本表。
  - 关键字段：`dataset_id`、`item_id`、`question`、`reference_answer`、`conversation_context`、`tags`
- `sophic_agent_eval_task`
  - 评测任务表。
  - 关键字段：`eval_task_id`、`task_name`、`eval_type`、`target_type`、`target_id`、`target_version`、`dataset_id`、`eval_config`、`operator_id`、`gmt_start`、`gmt_end`、`status`
- `sophic_agent_eval_result`
  - 评测结果表。
  - 关键字段：`result_id`、`eval_task_id`、`dataset_item_id`、`session_no`、`question`、`reference_answer`、`generated_answer`、`auto_score`、`manual_score`、`score_detail`、`status`
- `sophic_agent_perf_test_task`
  - 压测任务表。
  - 关键字段：`perf_task_id`、`task_name`、`target_type`、`target_id`、`target_version`、`concurrency_level`、`request_count`、`perf_config`、`result_summary`、`operator_id`、`gmt_start`、`gmt_end`、`status`

#### 模型管理流程

- 模型管理采用三层结构：
  - `sophic_agent_model_provider`
  - `sophic_agent_model`
  - `sophic_agent_model_config`

#### 供应商管理

- `sophic_agent_model_provider`
  - 用于维护模型供应商主数据。
  - 对齐 admin 的 `provider` 设计，承载供应商标识、协议、凭证和支持的模型类型。
- 典型场景
  - 平台预置 DashScope、OpenAI、Azure OpenAI 等供应商
  - 控制某个供应商是否可用
  - 维护供应商级通用 credential

#### 模型资产管理

- `sophic_agent_model`
  - 用于维护供应商下的模型资产清单。
  - 对齐 admin 的 `model` 设计，按 `provider_code + model_id` 组织模型定义。
- 典型场景
  - 为某个供应商登记 `qwen-max`、`qwen-plus`、`text-embedding-v3` 等模型
  - 标记模型类型，如 `LLM/EMBED/RERANK`
  - 控制模型是否在设计器中可选

#### 模型接入配置管理

- `sophic_agent_model_config`
  - 用于维护具体可执行的模型接入配置。
  - 对齐 admin 的 `model_config` 设计，承载 `base_url`、`api_key_cipher`、默认参数和可支持参数。
- 一个模型可对应多套配置，例如：
  - 测试环境配置
  - 生产环境配置
  - 不同研究所的独立接入配置
- 设计器和运行时应优先消费 `enabled=1` 且 `status=有效` 的模型配置。

#### 启停与可见性约定

- 供应商停用
  - `sophic_agent_model_provider.enabled=0`
  - 其下模型和模型配置默认不再对新建应用开放选择
- 模型停用
  - `sophic_agent_model.enabled=0`
  - 该模型不再在设计器候选列表中展示
- 模型配置停用
  - `sophic_agent_model_config.enabled=0`
  - 不再允许新任务绑定该配置
  - 已发布应用如仍引用该配置，应在发布校验或运行前给出告警

#### 设计器消费链路

1. 设计器先查询可用的 `sophic_agent_model_provider`
2. 再按供应商查询可用的 `sophic_agent_model`
3. 最后根据模型选择可用的 `sophic_agent_model_config`
4. 选中的配置标识写入 `sophic_agent_application_version.config_snapshot`
5. 运行时根据版本快照中的模型配置标识解析到实际 `base_url`、鉴权信息和默认参数

#### 运行时使用约定

- 运行时不直接依赖前端传入的供应商或模型名称。
- 运行时应根据应用版本快照中记录的 `model_config_id/config_id` 回查：
  - `sophic_agent_model_config`
  - `sophic_agent_model`
  - `sophic_agent_model_provider`
- 解析出最终调用参数：
  - 协议类型
  - 模型标识
  - 服务地址
  - API Key
  - 默认参数

#### 模型发布与变更影响规则

- 模型管理域中的发布，主要指模型供应商、模型资产、模型配置从“可维护状态”进入“可被设计器和运行时消费状态”。
- 生效判断建议同时满足：
  - `status=有效`
  - `enabled=1`

#### 配置变更规则

- 修改 `sophic_agent_model_provider`
  - 影响供应商级展示信息、协议声明和默认凭证。
  - 不应直接改写已发布应用版本中的模型快照。
- 修改 `sophic_agent_model`
  - 影响设计器候选模型列表和后续新版本的模型选择。
  - 不应直接改写已发布应用版本中的模型快照。
- 修改 `sophic_agent_model_config`
  - 影响运行时实际调用地址、鉴权信息和默认参数。
  - 属于高风险变更，应记录修改人和修改时间。

#### 对已发布应用的影响

- 已发布应用应固化引用 `model_config_id/config_id`。
- 已发布应用重新运行时，默认按当前有效的 `sophic_agent_model_config` 解析真实调用参数。
- 如果配置内容发生变更：
  - 不需要强制重新发布应用版本
  - 但应视为“底层模型接入配置变更”
  - 建议在发布记录或运行日志中保留配置版本快照或配置摘要
- 如果配置被停用：
  - 已发布应用在发布校验、启动运行或调试时应收到告警
  - 是否允许继续运行，建议由平台策略控制

#### 对运行中任务的影响

- 已启动任务在执行过程中，建议固定使用任务启动时解析出的模型参数。
- 不建议任务执行到一半因为后台修改了 `model_config` 而切换调用地址或 API Key。
- 建议在 `sophic_agent_task` 或 `sophic_agent_invoke_log` 中保留当次实际使用的模型配置摘要，例如：
  - `provider_code`
  - `model_id`
  - `base_url`
  - 参数快照摘要

#### 停用与删除规则

- 供应商停用
  - 不允许新建应用继续选择该供应商
  - 已发布应用若仍依赖其下配置，应触发运行前告警
- 模型停用
  - 不允许新建应用继续选择该模型
  - 已有版本不自动改绑其他模型
- 模型配置停用
  - 不允许新任务继续绑定该配置
  - 已发布应用如仍引用，建议标记为“待修复”
- 物理删除建议禁用
  - 优先采用 `status` 或 `enabled` 进行逻辑失效
  - 避免已发布应用、运行日志、评测任务出现悬挂引用

#### 发布校验建议

- 应用发布前，建议校验：
  - 关联的 `sophic_agent_model_provider` 是否可用
  - 关联的 `sophic_agent_model` 是否可用
  - 关联的 `sophic_agent_model_config` 是否可用
  - `base_url`、`api_key_cipher`、默认参数是否完整
- 校验失败时：
  - 不允许发布为应用
  - 不允许发布为工具
  - 返回明确的模型配置缺失或失效原因

## 4. 关键关系

### 4.1 应用与设计器主链路

- `sophic_agent_agent_template` 1-N `sophic_agent_application`
- `sophic_agent_application` 1-N `sophic_agent_application_version`
- `sophic_agent_application_version` 1-0/1 `sophic_agent_agent_schema`
- `sophic_agent_application_version` 1-N `sophic_agent_application_binding`
- `sophic_agent_application_binding` 1-N `sophic_agent_application_binding_item`
- `sophic_agent_application` 1-N `sophic_agent_guardrail_rule`
- `sophic_agent_guardrail_rule` 1-N `sophic_agent_guardrail_fixed_reply`
- `sophic_agent_high_code_service` 1-N `sophic_agent_high_code_service_version`
- `sophic_agent_model_provider` 1-N `sophic_agent_model`
- `sophic_agent_model` 1-N `sophic_agent_model_config`

### 4.2 运行时与会话链路

- `sophic_agent_session` 1-N `sophic_agent_session_message`
- `sophic_agent_session` 1-N `sophic_agent_task`
- `sophic_agent_session_message` 1-1/N `sophic_agent_task`（用户消息触发执行）
- `sophic_agent_task` N-1 `sophic_agent_session_message`（`response_message_id` 指向最终回复消息）
- `sophic_agent_task` N-1 `sophic_agent_application_version`
- `sophic_agent_task` 1-N `sophic_agent_execution_step`
- `smc_application` 1-N `smc_service`
- `smc_service` 1-N `smc_instance`
- `sophic_agent_invoke_log` N-1 `sophic_agent_task`
- `sophic_agent_guardrail_fixed_reply` N-1 `sophic_agent_task`
- `sophic_agent_guardrail_fixed_reply` N-1 `sophic_agent_session`
- `sophic_agent_agent_feedback` N-1 `sophic_agent_task`
- `sophic_agent_agent_feedback` N-1 `sophic_agent_session`
- `sophic_agent_memory_short_term` N-1 `sophic_agent_session`

### 4.3 知识、工具、MCP、数据源链路

- `sophic_agent_knowledge_base` 1-N `sophic_agent_knowledge_document`
- `sophic_agent_knowledge_document` 1-N `sophic_agent_knowledge_chunk`
- `sophic_agent_tool` 1-N `sophic_agent_tool_version`
- `sophic_agent_tool` 1-N `sophic_agent_tool_debug_record`
- `sophic_agent_mcp_server` 1-N `sophic_agent_mcp_server_instance`
- `sophic_agent_datasource` 1-N `sophic_agent_datasource_table`
- `sophic_agent_datasource_table` 1-N `sophic_agent_datasource_field`
- `sophic_agent_datasource` 1-N `sophic_agent_datasource_relation`
- `sophic_agent_datasource` 1-N `sophic_agent_datasource_semantic_model`

### 4.4 记忆链路

- `sophic_agent_memory_library` 1-N `sophic_agent_memory_rule`
- `sophic_agent_memory_library` 1-N `sophic_agent_memory_long_term`
- `sophic_agent_memory_library` 1-N `sophic_agent_memory_entity`
- `sophic_agent_memory_library` 1-N `sophic_agent_memory_recall_test`
- `sophic_agent_memory_entity` 1-N `sophic_agent_memory_long_term`
- `sophic_agent_memory_long_term` 1-N `sophic_agent_memory_hit_record`

### 4.5 发布、评测、压测链路

- `sophic_agent_publish_record` N-1 `sophic_agent_application_version`
- `sophic_agent_eval_dataset` 1-N `sophic_agent_eval_dataset_item`
- `sophic_agent_eval_task` 1-N `sophic_agent_eval_result`
- `sophic_agent_eval_task` N-1 `sophic_agent_eval_dataset`
- `sophic_agent_eval_task` N-1 `sophic_agent_application_version`
- `sophic_agent_perf_test_task` N-1 `sophic_agent_application_version`

### 4.6 权限资源链路

- `sophic_agent_resource` 1-N `sophic_agent_resource_acl`
- `sophic_agent_resource` 1-1 / 1-N `sophic_agent_application`
- `sophic_agent_resource` 1-1 / 1-N `sophic_agent_high_code_service`
- `sophic_agent_resource` 1-1 / 1-N `sophic_agent_tool`
- `sophic_agent_resource` 1-1 / 1-N `sophic_agent_mcp_server`
- `sophic_agent_resource` 1-1 / 1-N `sophic_agent_knowledge_base`
- `sophic_agent_resource` 1-1 / 1-N `sophic_agent_datasource`
- `sophic_agent_resource` 1-1 / 1-N `sophic_agent_memory_library`

说明：

- `sophic_agent_resource` 是统一资源锚点，业务上通常与各资源主表按 `resource_type + resource_id` 建立一对一映射。
- `sophic_agent_resource_acl` 负责资源级授权，建议按 `(resource_id, subject_type, subject_id, permission_type)` 做唯一约束。
- `subject_type` 建议支持：`USER`、`GROUP`、`INSTITUTE`。
- `permission_type` 建议支持：`READ`、`WRITE`。
- `grant_type` 建议支持：`DIRECT`、`INHERITED`。
- `sophic_agent_task` 与 `sophic_agent_application_version` 的关联建议通过 `(agent_id, agent_version)` 建立。
- `sophic_agent_publish_record`、`sophic_agent_eval_task`、`sophic_agent_perf_test_task` 均建议按 `(asset_id/target_id, asset_version/target_version)` 关联到具体应用版本。

## 5. 状态机建议

- 资源：`0=DELETED,1=DRAFT,2=PUBLISHED,3=PUBLISHED_EDITING,4=ARCHIVED`
- 任务：`1=QUEUED,2=RUNNING,3=SUCCESS,4=FAILED,5=CANCELED,6=TIMEOUT`
- 步骤：`1=PENDING,2=RUNNING,3=SUCCESS,4=FAILED,5=SKIPPED`
- 发布：`1=DRAFT,2=PUBLISHED,3=OFFLINE,4=DELETED`
- 评测任务：`1=CREATED,2=RUNNING,3=FINISHED,4=FAILED`
- 文档索引状态：`1=PENDING,2=PROCESSING,3=COMPLETED,4=FAILED`

## 6. 核心索引建议

- `sophic_agent_agent_template(template_type, scene_type, status)`
- `sophic_agent_application(type, status)`
- `sophic_agent_application_version(agent_id, version)`
- `sophic_agent_application_binding(agent_id, agent_version)`
- `sophic_agent_task(session_id, trigger_message_id, status, gmt_start)`
- `sophic_agent_execution_step(task_id, step_no)`
- `smc_service(ref_application, type, update_time)`
- `smc_instance(service_id, enabled, update_time)`
- `sophic_agent_session(agent_id, user_id, gmt_last_active)`
- `sophic_agent_invoke_log(task_id, gmt_create)`
- `sophic_agent_runtime_metric(metric_name, collect_time)`
- `sophic_agent_knowledge_document(kb_id, index_status, status)`
- `sophic_agent_mcp_server(status, name)`
- `sophic_agent_datasource_field(datasource_id, table_id)`
- `sophic_agent_memory_long_term(memory_library_id, user_id, status, gmt_create)`
- `sophic_agent_publish_record(asset_type, asset_id, status)`
- `sophic_agent_eval_task(target_type, target_id, status)`
- `sophic_agent_guardrail_fixed_reply(rule_id, gmt_create)`

## 7. 结论

- 当前版本已经不再区分 V1 / V2，所有确定需要的表均合并为 V1 正式设计。
- 应用与设计器域以 `application + application_version + agent_schema + application_binding + application_binding_item + guardrail_rule` 为核心。
- 会话、反馈、护栏规则/固定输出配置、MCP 实例、记忆实体/验证等此前缺失的表已纳入正式设计。
- MCP、知识库相关表的字段设计已按 admin 项目的现有设计风格收敛。
- 这份文档可作为 SophicAgent 当前阶段的完整数据库设计基线。

## 8. 数据表明细

说明：

- 本节补充 SophicAgent 自建表和账号权限域中直接使用到的菜单表明细。
- `users`、`user_info`、`user_additional_info`、`user_login`、`user_sign`、`priv_group`、`priv_role`、`priv_permission`、`priv_group_role_relation`、`priv_role_permission_relation`、`priv_user_group_relation` 为现有系统复用表，字段以现网权限中心为准，此处不重复展开完整结构。

### 8.1 `sophic_agent_api_key`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `group_id` | `varchar(64)` | 外键，关联用户组或授权主体 |
| `user_id` | `varchar(64)` | 外键，关联用户 |
| `api_key` | `varchar(512)` | API 访问密钥 |
| `description` | `varchar(4096)` | 凭证说明 |
| `expired_at` | `datetime` | 过期时间 |
| `status` | `tinyint` | 状态，1 启用/0 禁用 |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |

### 8.2 `priv_menu_resource`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `varchar(32)` | 主键，菜单 id |
| `service_id` | `varchar(32)` | 关联服务 id |
| `type` | `varchar(32)` | 菜单类型，0 系统内部组件，1 自定义菜单 |
| `seq` | `int` | 菜单顺序 |
| `name` | `varchar(255)` | 菜单名称 |
| `route` | `varchar(255)` | 菜单路由 |
| `icon` | `varchar(80)` | 图标 |
| `params` | `varchar(4096)` | 路由参数 |
| `description` | `varchar(255)` | 菜单描述 |
| `fid` | `varchar(32)` | 父菜单 id，外键指向本表 `id` |

### 8.3 `priv_menu_access`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `per_id` | `varchar(32)` | 主键，权限 id，外键关联 `priv_permission.id` |
| `menu_id` | `varchar(32)` | 外键，关联 `priv_menu_resource.id` |
| `ele_id` | `varchar(32)` | 菜单元素 id，可为空，用于按钮/元素级控制 |

### 8.4 `sophic_agent_resource`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `varchar(64)` | 主键，资源注册表自身 id |
| `resource_id` | `varchar(64)` | 业务资源 id，如 `agent_id`、`tool_id`、`kb_id` |
| `resource_name` | `varchar(128)` | 资源名称 |
| `resource_type` | `varchar(32)` | 资源类型，如 APPLICATION/TOOL/KB |
| `creator_id` | `varchar(64)` | 创建人 |
| `create_time` | `datetime` | 创建时间 |
| `update_time` | `datetime` | 更新时间 |
| `owner_user_id` | `varchar(64)` | 资源所有人 |
| `ext_config` | `json` | 扩展配置 |
| `status` | `tinyint` | 状态 |

### 8.5 `sophic_agent_resource_acl`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `resource_id` | `varchar(64)` | 外键，关联 `sophic_agent_resource.resource_id` |
| `subject_type` | `varchar(32)` | 主体类型，`USER/GROUP/INSTITUTE` |
| `subject_id` | `varchar(64)` | 主体 id，关联用户/组/研究所 |
| `permission_type` | `varchar(32)` | 权限类型，`READ/WRITE` |
| `grant_type` | `varchar(32)` | 授权方式，`DIRECT/INHERITED` |
| `status` | `tinyint` | 状态 |
| `creator` | `varchar(64)` | 创建人 |
| `modifier` | `varchar(64)` | 修改人 |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |

### 8.6 `sophic_agent_agent_template`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `template_id` | `varchar(64)` | 业务主键，模板 id |
| `template_code` | `varchar(64)` | 模板编码 |
| `template_name` | `varchar(255)` | 模板名称 |
| `template_type` | `varchar(64)` | 模板类型，如通用问答、问数、报告等 |
| `scene_type` | `varchar(64)` | 场景类型 |
| `description` | `varchar(4096)` | 模板描述 |
| `agent_type` | `varchar(64)` | 默认 Agent 类型 |
| `schema_snapshot` | `json/longtext` | 模板结构快照 |
| `config_snapshot` | `json/longtext` | 模板默认配置快照 |
| `input_schema` | `json` | 默认入参定义 |
| `output_schema` | `json` | 默认出参定义 |
| `icon` | `varchar(255)` | 图标 |
| `tags` | `json` | 标签 |
| `sort_no` | `int` | 排序号 |
| `enabled` | `tinyint` | 是否启用 |
| `status` | `tinyint` | 状态 |
| `creator` | `varchar(64)` | 创建人 |
| `modifier` | `varchar(64)` | 修改人 |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |

### 8.7 `sophic_agent_application`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `agent_id` | `varchar(64)` | 业务主键，应用 id，唯一 |
| `agent_code` | `varchar(64)` | 应用编码 |
| `name` | `varchar(255)` | 应用名称 |
| `description` | `varchar(4096)` | 应用描述 |
| `icon` | `varchar(255)` | 图标 |
| `source` | `varchar(64)` | 来源，如 `console/import/builtin` |
| `type` | `varchar(64)` | 应用类型，`agent/workflow` |
| `agent_scope` | `varchar(64)` | 应用范围，通用/专用/模板等 |
| `scene_type` | `varchar(64)` | 场景类型 |
| `latest_version` | `varchar(32)` | 最新版本号 |
| `published_version` | `varchar(32)` | 已发布版本号 |
| `tags` | `json` | 标签集合 |
| `status` | `tinyint` | 状态 |
| `creator` | `varchar(64)` | 创建人 |
| `modifier` | `varchar(64)` | 修改人 |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |

### 8.8 `sophic_agent_application_version`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `agent_id` | `varchar(64)` | 外键，关联 `sophic_agent_application.agent_id` |
| `version` | `varchar(32)` | 版本号 |
| `version_desc` | `varchar(4096)` | 版本说明 |
| `config_snapshot` | `json/longtext` | 应用完整配置快照，含 workflow DSL |
| `runtime_config` | `json` | 运行配置 |
| `input_schema` | `json` | 入参定义 |
| `output_schema` | `json` | 出参定义 |
| `dsl_schema` | `json` | DSL 导出快照 |
| `change_log` | `json` | 变更摘要 |
| `base_version` | `varchar(32)` | 派生来源版本 |
| `status` | `tinyint` | 版本状态 |
| `creator` | `varchar(64)` | 创建人 |
| `modifier` | `varchar(64)` | 修改人 |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |

### 8.9 `sophic_agent_agent_schema`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `agent_schema_id` | `varchar(64)` | 业务主键，schema id |
| `agent_id` | `varchar(64)` | 外键，关联 `sophic_agent_application.agent_id` |
| `version` | `varchar(32)` | 外键的一部分，关联应用版本 |
| `name` | `varchar(255)` | Agent 名称 |
| `description` | `varchar(4096)` | Agent 描述 |
| `agent_type` | `varchar(64)` | Agent 类型 |
| `instruction` | `longtext` | 系统提示词/指令 |
| `input_keys` | `json` | 输入键定义 |
| `output_key` | `varchar(255)` | 输出键 |
| `handle_config` | `json` | 处理器配置 |
| `sub_agents` | `json` | 子 Agent 配置 |
| `yaml_schema` | `longtext` | YAML 配置快照 |
| `enabled` | `tinyint` | 是否启用 |
| `status` | `varchar(64)` | 状态 |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |

### 8.10 `sophic_agent_application_binding`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `binding_id` | `varchar(64)` | 业务主键，绑定 id |
| `agent_id` | `varchar(64)` | 外键，关联应用 |
| `agent_version` | `varchar(32)` | 外键的一部分，关联应用版本 |
| `resource_type` | `varchar(64)` | 资源类型，如知识库、工具、数据源 |
| `resource_id` | `varchar(64)` | 外键，关联 `sophic_agent_resource.resource_id` 或对应业务资源 |
| `resource_name` | `varchar(255)` | 资源名称快照 |
| `binding_source` | `varchar(64)` | 绑定来源 |
| `sort_no` | `int` | 排序号 |
| `enabled` | `tinyint` | 启用状态 |
| `binding_config` | `json` | 挂载配置 |
| `status` | `tinyint` | 状态 |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |

### 8.11 `sophic_agent_application_binding_item`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `binding_id` | `varchar(64)` | 外键，关联 `sophic_agent_application_binding.binding_id` |
| `item_type` | `varchar(64)` | 明细类型，如 `TABLE/FIELD/MCP_TOOL` |
| `item_id` | `varchar(128)` | 明细项 id |
| `item_name` | `varchar(255)` | 明细项名称 |
| `item_path` | `varchar(512)` | 逻辑路径 |
| `item_config` | `json` | 明细配置 |
| `sort_no` | `int` | 排序号 |
| `status` | `tinyint` | 状态 |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |

### 8.12 `sophic_agent_high_code_service`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `service_id` | `varchar(64)` | 业务主键，服务 id，建议复用 `smc_service.id` |
| `service_code` | `varchar(64)` | 服务编码，面向业务展示与管理 |
| `name` | `varchar(255)` | 服务名称 |
| `service_type` | `varchar(64)` | 服务类型，如 Java/Python |
| `runtime_type` | `varchar(64)` | 运行时类型 |
| `owner_user_id` | `varchar(64)` | 负责人用户 id |
| `latest_version` | `varchar(32)` | 最新版本号 |
| `status` | `tinyint` | 状态 |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |

### 8.13 `sophic_agent_high_code_service_version`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `service_id` | `varchar(64)` | 外键，关联 `sophic_agent_high_code_service.service_id` |
| `version` | `varchar(32)` | 版本号 |
| `package_type` | `varchar(32)` | 制品类型，如 `jar/docker` |
| `package_uri` | `varchar(512)` | 制品地址 |
| `deploy_config` | `json` | 部署配置 |
| `input_schema` | `json` | 入参定义 |
| `output_schema` | `json` | 出参定义 |
| `change_log` | `json` | 变更说明 |
| `status` | `tinyint` | 状态 |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |

### 8.14 `sophic_agent_model_provider`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `provider_code` | `varchar(64)` | 业务主键，供应商编码 |
| `provider_key` | `varchar(255)` | 供应商唯一标识，参考 admin `provider.provider` |
| `icon` | `varchar(255)` | 供应商图标 |
| `name` | `varchar(255)` | 供应商名称 |
| `description` | `varchar(1024)` | 供应商说明 |
| `protocol` | `varchar(64)` | 接入协议，如 `openai` |
| `credential` | `json` | 凭证配置，参考 admin `provider.credential` |
| `supported_model_types` | `varchar(255)` | 支持的模型类型集合 |
| `source` | `varchar(64)` | 来源，如 `preset/custom` |
| `enabled` | `tinyint` | 是否启用 |
| `status` | `tinyint` | 状态 |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |
| `creator` | `varchar(64)` | 创建人 |
| `modifier` | `varchar(64)` | 修改人 |

### 8.15 `sophic_agent_model`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `model_code` | `varchar(64)` | 业务主键，模型编码 |
| `provider_code` | `varchar(64)` | 外键，关联 `sophic_agent_model_provider.provider_code` |
| `model_id` | `varchar(100)` | 模型标识，参考 admin `model.model_id` |
| `name` | `varchar(255)` | 模型名称 |
| `icon` | `varchar(255)` | 模型图标 |
| `model_type` | `varchar(64)` | 模型类型，如 `LLM/EMBED/RERANK` |
| `mode` | `varchar(64)` | 调用模式 |
| `tags` | `varchar(255)` | 模型标签 |
| `source` | `varchar(64)` | 来源，如 `preset/custom` |
| `enabled` | `tinyint` | 是否启用 |
| `status` | `tinyint` | 状态 |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |
| `creator` | `varchar(64)` | 创建人 |
| `modifier` | `varchar(64)` | 修改人 |

### 8.15.1 `sophic_agent_model_config`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `config_id` | `varchar(64)` | 业务主键，模型配置 ID |
| `config_name` | `varchar(100)` | 配置名称，参考 admin `model_config.name` |
| `provider_code` | `varchar(64)` | 外键，关联 `sophic_agent_model_provider.provider_code` |
| `model_code` | `varchar(64)` | 外键，关联 `sophic_agent_model.model_code` |
| `base_url` | `varchar(500)` | 模型服务地址，参考 admin `model_config.base_url` |
| `api_key_cipher` | `varchar(500)` | API Key 密文字段，参考 admin `model_config.api_key` |
| `default_parameters` | `json` | 默认参数配置，参考 admin `model_config.default_parameters` |
| `supported_parameters` | `json` | 支持的参数定义，参考 admin `model_config.supported_parameters` |
| `enabled` | `tinyint` | 是否启用 |
| `status` | `tinyint` | 状态 |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |
| `creator` | `varchar(64)` | 创建人 |
| `modifier` | `varchar(64)` | 修改人 |

### 8.16 `sophic_agent_session`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `session_id` | `varchar(64)` | 业务主键，会话 id |
| `agent_id` | `varchar(64)` | 外键，关联应用 |
| `agent_version` | `varchar(32)` | 应用版本 |
| `user_id` | `varchar(64)` | 外键，关联用户 |
| `session_title` | `varchar(255)` | 会话标题 |
| `source_type` | `varchar(64)` | 会话来源 |
| `gmt_last_active` | `datetime` | 最后活跃时间 |
| `status` | `tinyint` | 状态 |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |

### 8.17 `sophic_agent_session_message`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `session_id` | `varchar(64)` | 外键，关联 `sophic_agent_session.session_id` |
| `message_id` | `varchar(64)` | 业务主键，消息 id |
| `seq_no` | `int` | 消息顺序 |
| `role` | `varchar(32)` | 消息角色，如 user/assistant/system |
| `content` | `longtext` | 消息内容 |
| `content_type` | `varchar(32)` | 内容类型 |
| `token_usage` | `json` | token 消耗信息 |
| `metadata` | `json` | 扩展信息 |
| `gmt_create` | `datetime` | 创建时间 |

### 8.18 `sophic_agent_task`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `task_id` | `varchar(64)` | 业务主键，任务 id |
| `session_id` | `varchar(64)` | 外键，关联会话 |
| `trigger_message_id` | `varchar(64)` | 外键，关联触发本次执行的用户消息 |
| `response_message_id` | `varchar(64)` | 外键，关联本次执行生成的最终回复消息 |
| `agent_id` | `varchar(64)` | 外键，关联应用 |
| `agent_version` | `varchar(32)` | 外键的一部分，关联应用版本 |
| `task_type` | `varchar(64)` | 任务类型 |
| `task_name` | `varchar(255)` | 任务名称/本轮执行摘要 |
| `progress` | `int` | 执行进度 |
| `input_payload` | `json` | 输入数据 |
| `output_payload` | `json` | 输出数据 |
| `final_result` | `json/longtext` | 本次执行最终结果摘要 |
| `error_code` | `varchar(64)` | 错误码 |
| `error_message` | `varchar(1024)` | 错误信息 |
| `gmt_start` | `datetime` | 开始时间 |
| `gmt_end` | `datetime` | 结束时间 |
| `status` | `tinyint` | 状态 |

### 8.20 `sophic_agent_execution_step`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `task_id` | `varchar(64)` | 外键，关联任务 |
| `step_no` | `int` | 步骤序号 |
| `step_id` | `varchar(64)` | 业务主键，步骤 id |
| `step_type` | `varchar(64)` | 步骤类型 |
| `step_name` | `varchar(255)` | 步骤名称 |
| `step_desc` | `varchar(1024)` | 步骤说明，描述该步骤做了什么 |
| `executor_type` | `varchar(64)` | 执行器类型，如 LLM/TOOL/MCP/RAG/WORKFLOW/CODE |
| `tool_ref` | `varchar(128)` | 工具或能力引用标识 |
| `input_snapshot` | `json` | 步骤输入快照 |
| `output_snapshot` | `json` | 步骤输出快照 |
| `thought_snapshot` | `json/longtext` | 中间推理、路由判断、检索摘要等过程信息 |
| `cost_ms` | `bigint` | 执行耗时毫秒 |
| `error_code` | `varchar(64)` | 错误码 |
| `error_message` | `varchar(1024)` | 错误信息 |
| `status` | `tinyint` | 状态 |

### 8.22 `sophic_agent_knowledge_base`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `kb_id` | `varchar(64)` | 业务主键，知识库 id |
| `type` | `varchar(64)` | 知识库类型 |
| `status` | `tinyint` | 状态 |
| `name` | `varchar(255)` | 知识库名称 |
| `description` | `varchar(4096)` | 知识库描述 |
| `process_config` | `text/json` | 处理配置 |
| `index_config` | `text/json` | 索引配置 |
| `search_config` | `text/json` | 检索配置 |
| `total_docs` | `bigint unsigned` | 文档总数 |
| `creator` | `varchar(64)` | 创建人 |
| `modifier` | `varchar(64)` | 修改人 |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |

### 8.23 `sophic_agent_knowledge_document`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `kb_id` | `varchar(64)` | 外键，关联知识库 |
| `doc_id` | `varchar(64)` | 业务主键，文档 id |
| `type` | `varchar(64)` | 文档来源类型，如 file/url |
| `status` | `tinyint` | 状态 |
| `enabled` | `tinyint` | 是否启用 |
| `name` | `varchar(255)` | 文档名称 |
| `format` | `varchar(64)` | 文档格式 |
| `size` | `bigint` | 文档大小 |
| `metadata` | `text/json` | 元数据 |
| `index_status` | `tinyint` | 索引状态 |
| `path` | `varchar(512)` | 存储路径 |
| `parsed_path` | `varchar(512)` | 解析产物路径 |
| `process_config` | `text/json` | 分片处理配置 |
| `source` | `varchar(255)` | 文档来源描述 |
| `error` | `text` | 处理错误信息 |
| `creator` | `varchar(64)` | 创建人 |
| `modifier` | `varchar(64)` | 修改人 |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |

### 8.24 `sophic_agent_knowledge_chunk`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `kb_id` | `varchar(64)` | 外键，关联知识库 |
| `doc_id` | `varchar(64)` | 外键，关联文档 |
| `chunk_id` | `varchar(64)` | 业务主键，分片 id |
| `content` | `longtext` | 分片内容 |
| `metadata` | `json` | 分片元数据 |
| `vector_id` | `varchar(128)` | 向量索引 id |
| `status` | `tinyint` | 状态 |

### 8.25 `sophic_agent_tool`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `tool_id` | `varchar(64)` | 业务主键，工具 id |
| `tool_code` | `varchar(64)` | 工具编码 |
| `name` | `varchar(255)` | 工具名称 |
| `description` | `varchar(4096)` | 工具描述 |
| `tool_type` | `varchar(64)` | 工具类型 |
| `source` | `varchar(64)` | 来源 |
| `source_asset_type` | `varchar(32)` | 来源资产类型，支持 `AGENT`、`WORKFLOW` |
| `source_asset_id` | `varchar(64)` | 来源资产 id |
| `source_asset_version` | `varchar(32)` | 来源资产版本 |
| `publish_id` | `varchar(64)` | 外键，关联 `sophic_agent_publish_record.publish_id` |
| `api_schema` | `longtext` | 接口 schema |
| `config` | `longtext` | 工具配置 |
| `test_status` | `tinyint` | 测试状态，1 未测试/2 通过/3 失败 |
| `enabled` | `tinyint` | 是否启用 |
| `latest_version` | `varchar(32)` | 最新版本 |
| `status` | `tinyint` | 状态 |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |
| `creator` | `varchar(64)` | 创建人 |
| `modifier` | `varchar(64)` | 修改人 |

### 8.26 `sophic_agent_tool_version`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `tool_id` | `varchar(64)` | 外键，关联工具 |
| `version` | `varchar(32)` | 版本号 |
| `version_desc` | `varchar(4096)` | 版本说明 |
| `schema_snapshot` | `longtext` | schema 快照 |
| `config_snapshot` | `longtext` | 配置快照 |
| `status` | `tinyint` | 状态 |
| `gmt_create` | `datetime` | 创建时间 |

### 8.27 `sophic_agent_tool_debug_record`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `tool_id` | `varchar(64)` | 外键，关联工具 |
| `request_payload` | `json/longtext` | 调试请求 |
| `response_payload` | `json/longtext` | 调试响应 |
| `success` | `tinyint` | 是否成功 |
| `error_message` | `varchar(1024)` | 错误信息 |
| `cost_ms` | `bigint` | 耗时 |
| `gmt_create` | `datetime` | 创建时间 |

### 8.28 `sophic_agent_mcp_server`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `server_code` | `varchar(64)` | 业务主键，MCP 服务编码 |
| `name` | `varchar(64)` | 服务名称 |
| `description` | `varchar(1024)` | 服务描述 |
| `source` | `varchar(128)` | 服务来源 |
| `deploy_env` | `varchar(16)` | 部署环境，如 local/remote |
| `type` | `varchar(32)` | 服务类型，如 OFFICIAL/CUSTOMER |
| `deploy_config` | `text/json` | 部署配置 |
| `user_id` | `varchar(64)` | 所有者用户 id |
| `status` | `tinyint` | 状态 |
| `biz_type` | `varchar(512)` | 业务类型 |
| `detail_config` | `text/json` | 服务详情配置 |
| `host` | `varchar(1024)` | 服务地址 |
| `install_type` | `varchar(32)` | 安装方式，如 npx/uvx/sse |
| `gmt_create` | `datetime` | 创建时间 |
| `gmt_modified` | `datetime` | 修改时间 |
| `creator` | `varchar(64)` | 创建人 |
| `modifier` | `varchar(64)` | 修改人 |

### 8.29 `sophic_agent_mcp_server_instance`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `instance_id` | `varchar(64)` | 业务主键，实例 id |
| `server_code` | `varchar(64)` | 外键，关联 `sophic_agent_mcp_server.server_code` |
| `instance_name` | `varchar(255)` | 实例名称 |
| `endpoint` | `varchar(1024)` | 实例访问地址 |
| `health_status` | `varchar(32)` | 健康状态 |
| `runtime_status` | `varchar(32)` | 运行状态 |
| `gmt_last_heartbeat` | `datetime` | 最后心跳时间 |
| `metadata` | `json` | 扩展元数据 |

### 8.30 `sophic_agent_memory_short_term`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `session_id` | `varchar(64)` | 外键，关联会话 |
| `seq_no` | `int` | 对话轮次 |
| `role` | `varchar(32)` | 角色 |
| `content` | `longtext` | 记忆内容 |
| `metadata` | `json` | 扩展信息 |
| `expired_at` | `datetime` | 过期时间 |

### 8.32 `sophic_agent_memory_library`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `memory_library_id` | `varchar(64)` | 业务主键，记忆库 id |
| `library_code` | `varchar(64)` | 记忆库编码 |
| `name` | `varchar(255)` | 名称 |
| `description` | `varchar(4096)` | 描述 |
| `owner_user_id` | `varchar(64)` | 所有者 |
| `default_rule_id` | `varchar(64)` | 默认规则 id，外键关联 `sophic_agent_memory_rule.rule_id` |
| `permission_scope` | `varchar(64)` | 权限范围 |
| `status` | `tinyint` | 状态 |

### 8.33 `sophic_agent_memory_rule`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `rule_id` | `varchar(64)` | 业务主键，规则 id |
| `memory_library_id` | `varchar(64)` | 外键，关联记忆库 |
| `rule_name` | `varchar(255)` | 规则名称 |
| `extract_mode` | `varchar(64)` | 提取模式 |
| `expire_days` | `int` | 过期天数 |
| `rule_content` | `json/longtext` | 规则内容 |
| `status` | `tinyint` | 状态 |

### 8.34 `sophic_agent_memory_long_term`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `memory_library_id` | `varchar(64)` | 外键，关联记忆库 |
| `agent_id` | `varchar(64)` | 外键，关联应用 |
| `user_id` | `varchar(64)` | 外键，关联用户 |
| `memory_id` | `varchar(64)` | 业务主键，记忆 id |
| `entity_id` | `varchar(64)` | 外键，关联记忆实体 |
| `session_id` | `varchar(64)` | 外键，关联会话 |
| `content` | `longtext` | 原始记忆内容 |
| `summary_content` | `text` | 摘要内容 |
| `memory_type` | `varchar(64)` | 记忆类型 |
| `tags` | `json` | 标签 |
| `rule_snapshot` | `json` | 规则快照 |
| `metadata` | `json` | 扩展信息 |
| `embedding_ref` | `varchar(128)` | 向量引用 |
| `score` | `decimal(10,4)` | 评分/置信度 |
| `expired_at` | `datetime` | 过期时间 |
| `hit_count` | `int` | 命中次数 |
| `last_hit_time` | `datetime` | 最后命中时间 |
| `status` | `tinyint` | 状态 |

### 8.35 `sophic_agent_memory_hit_record`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `hit_id` | `varchar(64)` | 业务主键，命中记录 id |
| `memory_library_id` | `varchar(64)` | 外键，关联记忆库 |
| `memory_id` | `varchar(64)` | 外键，关联长期记忆 |
| `task_id` | `varchar(64)` | 外键，关联任务 |
| `query_text` | `text` | 查询文本 |
| `similarity_score` | `decimal(10,4)` | 相似度分数 |
| `status` | `tinyint` | 状态 |

### 8.36 `sophic_agent_memory_entity`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `entity_id` | `varchar(64)` | 业务主键，应用记忆归档 id |
| `memory_library_id` | `varchar(64)` | 外键，关联记忆库 |
| `agent_id` | `varchar(64)` | 外键，关联应用（智能体或工作流） |
| `entity_type` | `varchar(64)` | 归档对象类型，建议与应用类型保持一致 |
| `entity_name` | `varchar(255)` | 归档对象名称，通常取应用名称 |
| `entity_summary` | `text` | 应用记忆归档摘要 |
| `metadata` | `json` | 扩展信息 |
| `status` | `tinyint` | 状态 |

### 8.38 `sophic_agent_memory_recall_test`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `test_id` | `varchar(64)` | 业务主键，测试 id |
| `memory_library_id` | `varchar(64)` | 外键，关联记忆库 |
| `query_text` | `text` | 测试查询文本 |
| `expected_memory_id` | `varchar(64)` | 期望命中的记忆 id |
| `actual_result` | `json/longtext` | 实际召回结果 |
| `score_detail` | `json` | 评分明细 |
| `status` | `tinyint` | 状态 |

### 8.39 `sophic_agent_datasource`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `datasource_id` | `varchar(64)` | 业务主键，数据源 id |
| `datasource_code` | `varchar(64)` | 数据源编码 |
| `datasource_name` | `varchar(255)` | 数据源名称 |
| `schema_type` | `varchar(64)` | 模式类型 |
| `datasource_type` | `varchar(64)` | 数据源类型 |
| `host` | `varchar(255)` | 主机地址 |
| `port` | `int` | 端口 |
| `database_name` | `varchar(255)` | 数据库名 |
| `username` | `varchar(255)` | 用户名 |
| `password_cipher` | `varchar(512)` | 加密密码 |
| `connection_url` | `varchar(1024)` | 连接串 |
| `connect_config` | `json` | 连接配置 |
| `gmt_last_sync` | `datetime` | 最后同步时间 |
| `status` | `tinyint` | 状态 |

### 8.40 `sophic_agent_datasource_table`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `datasource_id` | `varchar(64)` | 外键，关联数据源 |
| `table_id` | `varchar(64)` | 业务主键，表 id |
| `schema_name` | `varchar(255)` | schema 名称 |
| `table_name` | `varchar(255)` | 表名 |
| `table_comment` | `varchar(1024)` | 表说明 |
| `refresh_version` | `varchar(64)` | 刷新版本 |
| `is_deleted` | `tinyint` | 逻辑删除标识 |
| `status` | `tinyint` | 状态 |

### 8.41 `sophic_agent_datasource_field`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `datasource_id` | `varchar(64)` | 外键，关联数据源 |
| `table_id` | `varchar(64)` | 外键，关联数据表 |
| `field_id` | `varchar(64)` | 业务主键，字段 id |
| `column_name` | `varchar(255)` | 字段名 |
| `column_comment` | `varchar(1024)` | 字段说明 |
| `data_type` | `varchar(64)` | 数据类型 |
| `is_primary` | `tinyint` | 是否主键 |
| `is_foreign` | `tinyint` | 是否外键 |
| `is_not_null` | `tinyint` | 是否非空 |
| `field_status` | `varchar(64)` | 字段状态 |
| `refresh_version` | `varchar(64)` | 刷新版本 |
| `is_deleted` | `tinyint` | 逻辑删除标识 |
| `status` | `tinyint` | 状态 |

### 8.42 `sophic_agent_datasource_relation`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `relation_id` | `varchar(64)` | 业务主键，关系 id |
| `datasource_id` | `varchar(64)` | 外键，关联数据源 |
| `source_table_id` | `varchar(64)` | 外键，源表 id |
| `target_table_id` | `varchar(64)` | 外键，目标表 id |
| `source_field_name` | `varchar(255)` | 源字段名 |
| `target_field_name` | `varchar(255)` | 目标字段名 |
| `relation_type` | `varchar(64)` | 关系类型 |
| `description` | `varchar(1024)` | 关系描述 |
| `status` | `tinyint` | 状态 |

### 8.43 `sophic_agent_datasource_semantic_model`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `semantic_id` | `varchar(64)` | 业务主键，语义模型 id |
| `datasource_id` | `varchar(64)` | 外键，关联数据源 |
| `table_id` | `varchar(64)` | 外键，关联数据表 |
| `field_id` | `varchar(64)` | 外键，关联字段 |
| `semantic_level` | `varchar(64)` | 语义层级 |
| `model_name` | `varchar(255)` | 模型名称 |
| `field_name` | `varchar(255)` | 展示字段名 |
| `business_name` | `varchar(255)` | 业务名称 |
| `synonyms` | `json` | 同义词 |
| `business_description` | `text` | 业务描述 |
| `metadata` | `json` | 扩展信息 |
| `status` | `tinyint` | 状态 |

### 8.44 `sophic_agent_invoke_log`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `trace_id` | `varchar(64)` | 链路追踪 id |
| `request_id` | `varchar(64)` | 请求 id |
| `task_id` | `varchar(64)` | 外键，关联任务 |
| `agent_id` | `varchar(64)` | 外键，关联应用 |
| `invoke_type` | `varchar(64)` | 调用类型 |
| `target_code` | `varchar(64)` | 调用目标编码 |
| `input_digest` | `varchar(512)` | 输入摘要 |
| `output_digest` | `varchar(512)` | 输出摘要 |
| `error_code` | `varchar(64)` | 错误码 |
| `error_message` | `varchar(1024)` | 错误信息 |
| `cost_ms` | `bigint` | 耗时 |
| `status` | `tinyint` | 状态 |
| `gmt_create` | `datetime` | 创建时间 |

### 8.45 `sophic_agent_runtime_metric`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `metric_scope` | `varchar(64)` | 指标范围 |
| `metric_name` | `varchar(128)` | 指标名称 |
| `metric_value` | `decimal(20,4)` | 指标值 |
| `metric_tags` | `json` | 指标标签 |
| `collect_time` | `datetime` | 采集时间 |

### 8.46 `sophic_agent_guardrail_rule`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `agent_id` | `varchar(64)` | 外键，关联应用（智能体或工作流） |
| `rule_id` | `varchar(64)` | 业务主键，规则 id |
| `rule_code` | `varchar(64)` | 规则编码 |
| `rule_type` | `varchar(64)` | 规则类型，如 INPUT/OUTPUT |
| `scope_type` | `varchar(64)` | 作用范围类型 |
| `scope_code` | `varchar(64)` | 作用范围编码 |
| `match_config` | `json` | 正则匹配配置 |
| `action_config` | `json` | 替换、屏蔽等动作配置 |
| `priority` | `int` | 优先级 |
| `enabled` | `tinyint` | 是否启用 |
| `status` | `tinyint` | 状态 |

### 8.47 `sophic_agent_guardrail_fixed_reply`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `agent_id` | `varchar(64)` | 外键，关联应用（智能体或工作流） |
| `record_id` | `varchar(64)` | 业务主键，固定输出配置 id |
| `rule_id` | `varchar(64)` | 关联规则 id，可为空，用于标识关联的规则干预配置 |
| `task_id` | `varchar(64)` | 关联任务，可为空 |
| `session_id` | `varchar(64)` | 关联会话，可为空 |
| `input_snapshot` | `json/longtext` | 固定问题或问题特征配置 |
| `output_snapshot` | `json/longtext` | 固定输出内容配置 |
| `action_result` | `json` | 干预动作配置结果，如命中阈值、回复策略等 |
| `gmt_create` | `datetime` | 创建时间 |

### 8.48 `sophic_agent_agent_feedback`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `agent_id` | `varchar(64)` | 外键，关联应用 |
| `task_id` | `varchar(64)` | 外键，关联任务 |
| `session_id` | `varchar(64)` | 外键，关联会话 |
| `user_id` | `varchar(64)` | 外键，关联用户 |
| `rating` | `int` | 评分 |
| `feedback_type` | `varchar(64)` | 反馈类型 |
| `content` | `text` | 反馈内容 |
| `status` | `tinyint` | 状态 |
| `gmt_create` | `datetime` | 创建时间 |

### 8.50 `sophic_agent_publish_record`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `publish_id` | `varchar(64)` | 业务主键，发布记录 id |
| `asset_type` | `varchar(64)` | 资产类型 |
| `asset_id` | `varchar(64)` | 资产 id，外键关联应用/工具/高代码服务 |
| `asset_version` | `varchar(32)` | 资产版本 |
| `publish_type` | `varchar(64)` | 发布类型，应用/工具 |
| `target_resource_id` | `varchar(64)` | 外键，关联统一资源 |
| `input_schema` | `json` | 发布入参定义 |
| `output_schema` | `json` | 发布出参定义 |
| `config_snapshot` | `json/longtext` | 发布配置快照 |
| `change_log` | `json` | 变更摘要 |
| `operator_id` | `varchar(64)` | 操作人 |
| `status` | `tinyint` | 状态 |

### 8.51 `sophic_agent_eval_dataset`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `dataset_id` | `varchar(64)` | 业务主键，评测集 id |
| `dataset_name` | `varchar(255)` | 评测集名称 |
| `dataset_type` | `varchar(64)` | 评测集类型 |
| `description` | `varchar(4096)` | 描述 |
| `owner_user_id` | `varchar(64)` | 所有者 |
| `status` | `tinyint` | 状态 |

### 8.52 `sophic_agent_eval_dataset_item`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `dataset_id` | `varchar(64)` | 外键，关联评测集 |
| `item_id` | `varchar(64)` | 业务主键，样本 id |
| `question` | `text` | 问题 |
| `reference_answer` | `text` | 参考答案 |
| `conversation_context` | `json/longtext` | 多轮上下文 |
| `tags` | `json` | 标签 |

### 8.53 `sophic_agent_eval_task`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `eval_task_id` | `varchar(64)` | 业务主键，评测任务 id |
| `task_name` | `varchar(255)` | 任务名称 |
| `eval_type` | `varchar(64)` | 评测类型，自动/手动 |
| `target_type` | `varchar(64)` | 评测目标类型 |
| `target_id` | `varchar(64)` | 目标 id，外键关联应用版本主体 |
| `target_version` | `varchar(32)` | 目标版本 |
| `dataset_id` | `varchar(64)` | 外键，关联评测集 |
| `eval_config` | `json` | 评测配置 |
| `operator_id` | `varchar(64)` | 操作人 |
| `gmt_start` | `datetime` | 开始时间 |
| `gmt_end` | `datetime` | 结束时间 |
| `status` | `tinyint` | 状态 |

### 8.54 `sophic_agent_eval_result`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `result_id` | `varchar(64)` | 业务主键，结果 id |
| `eval_task_id` | `varchar(64)` | 外键，关联评测任务 |
| `dataset_item_id` | `varchar(64)` | 外键，关联评测样本 |
| `session_no` | `int` | 会话序号 |
| `question` | `text` | 问题 |
| `reference_answer` | `text` | 参考答案 |
| `generated_answer` | `text` | 生成答案 |
| `auto_score` | `decimal(10,4)` | 自动评分 |
| `manual_score` | `decimal(10,4)` | 人工评分 |
| `score_detail` | `json` | 评分明细 |
| `status` | `tinyint` | 状态 |

### 8.55 `sophic_agent_perf_test_task`

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `bigint unsigned` | 主键 |
| `perf_task_id` | `varchar(64)` | 业务主键，压测任务 id |
| `task_name` | `varchar(255)` | 任务名称 |
| `target_type` | `varchar(64)` | 压测目标类型 |
| `target_id` | `varchar(64)` | 目标 id，外键关联应用/工具 |
| `target_version` | `varchar(32)` | 目标版本 |
| `concurrency_level` | `int` | 并发数 |
| `request_count` | `int` | 请求总数 |
| `perf_config` | `json` | 压测配置 |
| `result_summary` | `json` | 结果摘要 |
| `operator_id` | `varchar(64)` | 操作人 |
| `gmt_start` | `datetime` | 开始时间 |
| `gmt_end` | `datetime` | 结束时间 |
| `status` | `tinyint` | 状态 |

### 8.56 `smc_application`（已有）

| 属性名 | 类型 | 说明 |
|---|---|---|
| `application_id` | `varchar(32)` | 主键，应用 id |
| `application_name` | `varchar(50)` | 应用名 |
| `owner` | `varchar(32)` | 负责人 |
| `create_time` | `timestamp` | 创建时间 |
| `note` | `varchar(255)` | 描述 |
| `seq` | `int` | 排序 |

### 8.57 `smc_service`（已有）

| 属性名 | 类型 | 说明 |
|---|---|---|
| `id` | `varchar(64)` | 主键，服务 id |
| `service_name` | `varchar(255)` | 服务名称 |
| `source` | `varchar(32)` | 服务来源，如 Nacos |
| `params` | `varchar(1024)` | 服务启动参数，用于运行控制 |
| `type` | `varchar(32)` | 服务类型 |
| `create_time` | `datetime` | 服务创建时间 |
| `update_time` | `datetime` | 服务更新时间 |
| `note` | `varchar(255)` | 服务描述 |
| `version` | `varchar(255)` | 版本 |
| `service_info` | `varchar(50)` | 通用服务信息 |
| `ref_application` | `varchar(50)` | 外键，关联 `smc_application.application_id`，用于归属运行应用 |
| `seq` | `int` | 排序 |

### 8.58 `smc_instance`（已有）

| 属性名 | 类型 | 说明 |
|---|---|---|
| `instance_id` | `varchar(32)` | 主键，服务实例 id |
| `service_id` | `varchar(255)` | 外键，关联服务 id |
| `ip` | `varchar(64)` | IP 地址 |
| `port` | `int` | 端口 |
| `type` | `varchar(64)` | 类型 |
| `instance_mode` | `varchar(64)` | 运行模式 |
| `fingerprint` | `varchar(64)` | 服务指纹 |
| `enabled` | `tinyint(1)` | 是否可用 |
| `update_time` | `datetime` | 更新时间 |
| `insert_time` | `datetime` | 插入时间 |
| `version` | `varchar(50)` | 版本 |
| `last_offline_time` | `datetime` | 最近离线时间 |
| `weight` | `int` | 权重，默认 1 |
