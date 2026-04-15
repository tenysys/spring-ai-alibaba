# SophicAgent 数据库设计（V1 / V2）

## 1. 设计原则

- 多租户隔离：除明确复用平台公共表外，业务表统一带 `workspace_id`。
- 主键规范：统一使用 `id bigint unsigned auto_increment`，业务主键使用 `xxx_id` / `xxx_code`。
- 状态规范：统一使用 `status`；需要开关控制时补充 `enabled`。
- 时间规范：统一使用 `gmt_create`、`gmt_modified`；运行态补充 `gmt_start`、`gmt_end`。
- 扩展字段：复杂配置优先使用 `json`，承载快照、策略、DSL、扩展元数据。
- 版本化：应用、工作流、工具、高代码服务统一采用“定义表 + 版本表”模式。
- 账号权限域：沿用现有权限与认证服务的既有模型和数据表，SophicAgent 只做业务关联，不改造该域设计。

## 2. 覆盖结论

### 2.1 当前设计已能覆盖的核心能力

- 应用资产管理：应用、版本、工作流定义、资源绑定。
- 设计器能力：工作流编排、模型配置、工具绑定、知识库绑定、数据源绑定、记忆绑定。
- 运行时能力：事件接入、任务执行、执行计划、执行步骤、任务调度。
- 能力资产：知识库、文档、分片、工具、MCP 服务、短期记忆、工作记忆。
- 数据语义：数据源、表、字段、关系、语义模型。
- 治理观测：调用日志、审计、运行指标、告警、故障处理。
- V2 扩展：长期记忆、限流与高可用、发布、评测、压测。

### 2.2 当前设计仍有缺口，若要完整支撑功能设计，建议补充以下表

- 会话与消息：
  - `sophic_agent_session`
  - `sophic_agent_session_message`
- 应用运营行为：
  - `sophic_agent_agent_favorite`
  - `sophic_agent_agent_recent_visit`
  - `sophic_agent_agent_feedback`
- 干预与护栏：
  - `sophic_agent_guardrail_rule`
  - `sophic_agent_guardrail_record`
- MCP 实例管理：
  - `sophic_agent_mcp_server_instance`
- 记忆增强细化：
  - `sophic_agent_memory_entity`
  - `sophic_agent_memory_extract_log`
  - `sophic_agent_memory_recall_test`

说明：
- 如果这些能力暂不在 V1 落地，可先不建表，但从“功能设计完全覆盖”的角度看，当前版本还不能算 100% 闭环。

## 3. V1 表设计

### 3.1 账号权限域

该域由现有权限与认证服务统一处理，SophicAgent 按你最初的接入方式直接依赖现有表，不复用当前代码中的另一套账号模型。

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

### 3.2 应用与设计器域

- `sophic_agent_application`
  - 应用主表，承载通用智能体、专用智能体、工作流型应用。
  - 关键字段：`agent_id`、`agent_code`、`name`、`agent_scope`、`scene_type`、`latest_version`、`tags`、`status`
- `sophic_agent_application_version`
  - 应用版本表。
  - 关键字段：`agent_id`、`version`、`version_desc`、`config_snapshot`、`workflow_definition_id`、`runtime_config`、`status`
- `sophic_agent_high_code_service`
  - 高代码服务主表。
  - 关键字段：`service_id`、`service_code`、`name`、`service_type`、`runtime_type`、`owner_account_id`、`latest_version`、`status`
- `sophic_agent_high_code_service_version`
  - 高代码服务版本表。
  - 关键字段：`service_id`、`version`、`package_type`、`package_uri`、`deploy_config`、`input_schema`、`output_schema`、`status`
- `sophic_agent_model_provider`
  - 模型供应商表。
  - 关键字段：`provider_code`、`name`、`protocol`、`credential`、`status`
- `sophic_agent_model`
  - 模型定义表。
  - 关键字段：`model_code`、`provider_code`、`model_name`、`model_type`、`mode`、`model_params`、`status`
- `sophic_agent_workflow_definition`
  - 工作流定义主表。
  - 关键字段：`definition_id`、`name`、`description`、`latest_version`、`status`
- `sophic_agent_workflow_version`
  - 工作流版本表。
  - 关键字段：`definition_id`、`version`、`version_desc`、`definition_snapshot`、`status`
- `sophic_agent_workflow_node`
  - 工作流节点表。
  - 关键字段：`definition_id`、`version`、`node_id`、`node_type`、`node_name`、`node_config`
- `sophic_agent_workflow_edge`
  - 工作流边表。
  - 关键字段：`definition_id`、`version`、`source_node_id`、`target_node_id`、`source_handle`、`target_handle`、`edge_config`
- `sophic_agent_application_binding`
  - 应用资源绑定表。
  - 关键字段：`agent_id`、`agent_version`、`resource_type`、`resource_id`、`binding_source`、`sort_no`、`enabled`、`binding_config`
- `sophic_agent_application_binding_item`
  - 绑定明细表，支持 MCP 工具、表、字段、概念等细粒度绑定。
  - 关键字段：`binding_id`、`item_type`、`item_id`、`item_name`、`item_config`、`sort_no`

### 3.3 运行时域

- `sophic_agent_runtime_event`
  - 运行事件接入表。
  - 关键字段：`event_id`、`event_type`、`source_system`、`payload`、`authorized`、`route_agent_id`、`status`
- `sophic_agent_task`
  - 任务主表。
  - 关键字段：`task_id`、`conversation_id`、`agent_id`、`agent_version`、`task_type`、`trigger_event_id`、`priority`、`progress`、`input_payload`、`output_payload`、`error_code`、`error_message`、`gmt_start`、`gmt_end`、`status`
- `sophic_agent_execution_plan`
  - 执行计划表。
  - 关键字段：`task_id`、`plan_id`、`plan_content`、`decision_policy`、`risk_review`、`status`
- `sophic_agent_execution_step`
  - 执行步骤表。
  - 关键字段：`task_id`、`plan_id`、`step_no`、`step_id`、`step_type`、`step_name`、`step_input`、`step_output`、`cost_ms`、`error_code`、`error_message`、`status`
- `sophic_agent_task_queue`
  - 调度队列表。
  - 关键字段：`queue_name`、`task_id`、`priority`、`scheduler_node`、`gmt_schedule`、`status`

### 3.4 能力资产域

- `sophic_agent_knowledge_base`
  - 知识库主表。
  - 关键字段：`kb_id`、`name`、`kb_type`、`process_config`、`index_config`、`search_config`、`permission_scope`、`total_docs`、`status`
- `sophic_agent_resource`
  - 统一资源注册表。
  - 关键字段：`resource_id`、`resource_name`、`resource_type`、`source_system`、`resource_code`、`owner_account_id`、`ext_config`、`status`
- `sophic_agent_knowledge_document`
  - 知识文档表。
  - 关键字段：`kb_id`、`doc_id`、`name`、`doc_type`、`format`、`source`、`metadata`、`index_status`、`enabled`、`error_msg`、`status`
- `sophic_agent_knowledge_chunk`
  - 知识分片表。
  - 关键字段：`kb_id`、`doc_id`、`chunk_id`、`content`、`metadata`、`vector_id`、`status`
- `sophic_agent_tool`
  - 工具主表。
  - 关键字段：`tool_id`、`tool_code`、`name`、`tool_type`、`source`、`api_schema`、`config`、`enabled`、`latest_version`、`status`
- `sophic_agent_tool_version`
  - 工具版本表。
  - 关键字段：`tool_id`、`version`、`version_desc`、`schema_snapshot`、`config_snapshot`、`status`
- `sophic_agent_tool_debug_record`
  - 工具调试记录。
  - 关键字段：`tool_id`、`request_payload`、`response_payload`、`success`、`error_message`、`cost_ms`
- `sophic_agent_mcp_server`
  - MCP 服务主表。
  - 关键字段：`server_code`、`name`、`server_type`、`install_type`、`host`、`deploy_config`、`detail_config`、`status`
- `sophic_agent_memory_short_term`
  - 短期记忆表。
  - 关键字段：`session_id`、`seq_no`、`role`、`content`、`metadata`、`expired_at`
- `sophic_agent_memory_working`
  - 工作记忆表。
  - 关键字段：`task_id`、`memory_key`、`memory_value`

### 3.5 数据源与语义域

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

### 3.6 治理观测域

- `sophic_agent_invoke_log`
  - 调用日志。
  - 关键字段：`trace_id`、`request_id`、`task_id`、`agent_id`、`invoke_type`、`target_code`、`input_digest`、`output_digest`、`error_code`、`error_message`、`cost_ms`、`status`
- `sophic_agent_audit_event`
  - 审计事件。
  - 关键字段：`audit_id`、`operator_id`、`event_type`、`resource_type`、`resource_code`、`action`、`result`、`detail`、`trace_id`
- `sophic_agent_runtime_metric`
  - 运行指标。
  - 关键字段：`metric_scope`、`metric_name`、`metric_value`、`metric_tags`、`collect_time`
- `sophic_agent_alarm_rule`
  - 告警规则。
  - 关键字段：`rule_code`、`name`、`metric_name`、`expr`、`severity`、`enabled`
- `sophic_agent_alarm_record`
  - 告警记录。
  - 关键字段：`alarm_id`、`rule_code`、`metric_name`、`trigger_value`、`severity`、`detail`、`trigger_time`、`recover_time`、`status`
- `sophic_agent_fault_record`
  - 故障记录。
  - 关键字段：`fault_id`、`task_id`、`source_type`、`source_code`、`fault_type`、`severity`、`error_code`、`error_message`、`status`
- `sophic_agent_fault_process_record`
  - 故障处理记录。
  - 关键字段：`fault_id`、`action_type`、`action_detail`、`result`、`operator_id`

## 4. V2 增强表设计

### 4.1 记忆增强主表（运行态）

这一组表用于支撑记忆能力的生产运行主链路，解决“记忆存储、规则控制、在线召回、命中留痕”问题。

- `sophic_agent_memory_long_term`
  - 长期记忆明细，保存真正被沉淀下来的记忆内容。
  - 关键字段：`memory_library_id`、`agent_id`、`user_id`、`memory_id`、`entity_id`、`session_id`、`content`、`summary_content`、`memory_type`、`tags`、`rule_snapshot`、`metadata`、`embedding_ref`、`score`、`expired_at`、`hit_count`、`last_hit_time`、`status`
- `sophic_agent_memory_library`
  - 记忆库主表，定义记忆归属、权限与默认规则。
  - 关键字段：`memory_library_id`、`library_code`、`name`、`description`、`owner_account_id`、`default_rule_id`、`permission_scope`、`status`
- `sophic_agent_memory_rule`
  - 记忆规则表，定义抽取、过期、沉淀等策略。
  - 关键字段：`rule_id`、`memory_library_id`、`rule_name`、`extract_mode`、`expire_days`、`rule_content`、`status`
- `sophic_agent_memory_hit_record`
  - 记忆命中记录，记录线上真实任务中的召回命中情况。
  - 关键字段：`hit_id`、`memory_library_id`、`memory_id`、`task_id`、`query_text`、`similarity_score`、`status`

### 4.2 统计与治理增强

- `sophic_agent_invoke_stat_daily`
  - 调用日统计。
  - 关键字段：`stat_date`、`dim_type`、`dim_code`、`invoke_count`、`success_count`、`fail_count`、`avg_cost_ms`、`token_in`、`token_out`
- `sophic_agent_traffic_limit_rule`
  - 限流规则。
  - 关键字段：`rule_code`、`scope`、`scope_code`、`qps_limit`、`concurrency_limit`、`burst_limit`、`enabled`
- `sophic_agent_concurrent_quota`
  - 并发配额。
  - 关键字段：`resource_group`、`quota_total`、`quota_used`、`enabled`
- `sophic_agent_ha_node`
  - 高可用节点。
  - 关键字段：`node_id`、`service_group`、`node_role`、`health_status`、`resource_usage`、`gmt_last_heartbeat`
- `sophic_agent_ha_switch_record`
  - 主备切换记录。
  - 关键字段：`switch_id`、`service_group`、`from_node_id`、`to_node_id`、`trigger_reason`、`result`
- `sophic_agent_runtime_config_history`
  - 运行配置变更历史。
  - 关键字段：`config_key`、`config_value`、`change_type`、`operator_id`
- `sophic_agent_integration_endpoint`
  - 外部接入点。
  - 关键字段：`endpoint_id`、`system_name`、`endpoint_type`、`endpoint_url`、`auth_config`、`status`
- `sophic_agent_integration_record`
  - 集成调用记录。
  - 关键字段：`target_id`、`request_payload`、`response_payload`、`error_message`、`cost_ms`、`status`
- `sophic_agent_deploy_plan`
  - 部署计划。
  - 关键字段：`plan_id`、`env`、`plan_content`、`status`、`operator_id`、`gmt_start`、`gmt_end`

### 4.3 发布与评测增强

- `sophic_agent_publish_record`
  - 发布记录。
  - 关键字段：`publish_id`、`asset_type`、`asset_id`、`asset_version`、`publish_type`、`target_resource_id`、`input_schema`、`output_schema`、`config_snapshot`、`change_log`、`operator_id`、`status`
- `sophic_agent_eval_dataset`
  - 评测集主表。
  - 关键字段：`dataset_id`、`dataset_name`、`dataset_type`、`description`、`owner_account_id`、`status`
- `sophic_agent_eval_dataset_item`
  - 评测集样本。
  - 关键字段：`dataset_id`、`item_id`、`question`、`reference_answer`、`conversation_context`、`tags`
- `sophic_agent_eval_task`
  - 评测任务。
  - 关键字段：`eval_task_id`、`task_name`、`eval_type`、`target_type`、`target_id`、`target_version`、`dataset_id`、`eval_config`、`operator_id`、`gmt_start`、`gmt_end`、`status`
- `sophic_agent_eval_result`
  - 评测结果。
  - 关键字段：`result_id`、`eval_task_id`、`dataset_item_id`、`session_no`、`question`、`reference_answer`、`generated_answer`、`auto_score`、`manual_score`、`score_detail`、`status`
- `sophic_agent_perf_test_task`
  - 压测任务。
  - 关键字段：`perf_task_id`、`task_name`、`target_type`、`target_id`、`target_version`、`concurrency_level`、`request_count`、`perf_config`、`result_summary`、`operator_id`、`gmt_start`、`gmt_end`、`status`

## 5. 建议补充表说明

### 5.1 会话与消息

- `sophic_agent_session`
  - 用于承载会话级状态，补足功能设计里的“会话管理、会话级执行记录、最近访问”。
  - 关键字段：`session_id`、`workspace_id`、`agent_id`、`agent_version`、`account_id`、`session_title`、`source_type`、`gmt_last_active`、`status`
- `sophic_agent_session_message`
  - 用于保存用户、助手、系统、多轮上下文消息。
  - 关键字段：`session_id`、`message_id`、`seq_no`、`role`、`content`、`content_type`、`token_usage`、`metadata`、`gmt_create`

### 5.2 应用运营行为

- `sophic_agent_agent_favorite`
  - 支撑收藏能力。
  - 关键字段：`workspace_id`、`account_id`、`agent_id`、`gmt_create`
- `sophic_agent_agent_recent_visit`
  - 支撑最近访问能力。
  - 关键字段：`workspace_id`、`account_id`、`agent_id`、`visit_count`、`gmt_last_visit`
- `sophic_agent_agent_feedback`
  - 支撑反馈入口和应用评价。
  - 关键字段：`workspace_id`、`agent_id`、`task_id`、`session_id`、`account_id`、`rating`、`feedback_type`、`content`、`status`

### 5.3 干预与护栏

- `sophic_agent_guardrail_rule`
  - 支撑敏感词、正则替换、标准回复、审核策略。
  - 关键字段：`rule_id`、`rule_code`、`rule_type`、`scope_type`、`scope_code`、`match_config`、`action_config`、`priority`、`enabled`、`status`
- `sophic_agent_guardrail_record`
  - 记录一次命中和干预结果。
  - 关键字段：`record_id`、`rule_id`、`task_id`、`session_id`、`input_snapshot`、`output_snapshot`、`action_result`、`gmt_create`

### 5.4 MCP 实例管理

- `sophic_agent_mcp_server_instance`
  - 支撑“服务实例列表、健康状态、运行控制”。
  - 关键字段：`instance_id`、`server_code`、`instance_name`、`endpoint`、`health_status`、`runtime_status`、`gmt_last_heartbeat`、`metadata`

### 5.5 记忆治理与验证补充表

这一组表不是记忆主链路最小必需集合，而是用于增强治理、分析、调试和效果验证能力。

- `sophic_agent_memory_entity`
  - 记忆实体表，可选。
  - 用于把长期记忆进一步抽象为实体对象，支撑实体级聚合和召回，不等同于 `sophic_agent_memory_long_term` 的原始记忆内容。
  - 关键字段：`entity_id`、`memory_library_id`、`entity_type`、`entity_name`、`entity_summary`、`metadata`、`status`
- `sophic_agent_memory_extract_log`
  - 记忆抽取日志表，可选。
  - 用于记录一次记忆抽取过程，偏调试与审计，不直接参与线上召回。
  - 关键字段：`extract_id`、`memory_library_id`、`task_id`、`rule_id`、`source_text`、`extract_result`、`status`
- `sophic_agent_memory_recall_test`
  - 记忆召回测试表，可选。
  - 用于离线命中率测试、相似度召回验证，与 `sophic_agent_memory_hit_record` 的线上真实命中日志分层。
  - 关键字段：`test_id`、`memory_library_id`、`query_text`、`expected_memory_id`、`actual_result`、`score_detail`、`status`

## 6. 关键关系

- `sophic_agent_application` 1-N `sophic_agent_application_version`
- `sophic_agent_application_version` 1-N `sophic_agent_application_binding`
- `sophic_agent_application_binding` 1-N `sophic_agent_application_binding_item`
- `sophic_agent_workflow_definition` 1-N `sophic_agent_workflow_version`
- `sophic_agent_workflow_version` 1-N `sophic_agent_workflow_node`
- `sophic_agent_workflow_version` 1-N `sophic_agent_workflow_edge`
- `sophic_agent_task` 1-N `sophic_agent_execution_plan`
- `sophic_agent_execution_plan` 1-N `sophic_agent_execution_step`
- `sophic_agent_knowledge_base` 1-N `sophic_agent_knowledge_document`
- `sophic_agent_knowledge_document` 1-N `sophic_agent_knowledge_chunk`
- `sophic_agent_tool` 1-N `sophic_agent_tool_version`
- `sophic_agent_datasource` 1-N `sophic_agent_datasource_table`
- `sophic_agent_datasource_table` 1-N `sophic_agent_datasource_field`
- `sophic_agent_datasource` 1-N `sophic_agent_datasource_relation`
- `sophic_agent_datasource` 1-N `sophic_agent_datasource_semantic_model`
- `sophic_agent_memory_library` 1-N `sophic_agent_memory_rule`
- `sophic_agent_memory_library` 1-N `sophic_agent_memory_long_term`
- `sophic_agent_eval_dataset` 1-N `sophic_agent_eval_dataset_item`
- `sophic_agent_eval_task` 1-N `sophic_agent_eval_result`
- `sophic_agent_fault_record` 1-N `sophic_agent_fault_process_record`
- `sophic_agent_session` 1-N `sophic_agent_session_message`
- `sophic_agent_mcp_server` 1-N `sophic_agent_mcp_server_instance`

## 7. 状态机建议

- 资源：`0=DELETED,1=DRAFT,2=PUBLISHED,3=ARCHIVED`
- 任务：`1=QUEUED,2=RUNNING,3=SUCCESS,4=FAILED,5=CANCELED,6=TIMEOUT`
- 步骤：`1=PENDING,2=RUNNING,3=SUCCESS,4=FAILED,5=SKIPPED`
- 发布：`1=DRAFT,2=PUBLISHED,3=OFFLINE,4=DELETED`
- 评测任务：`1=CREATED,2=RUNNING,3=FINISHED,4=FAILED`

## 8. 核心索引建议

- `sophic_agent_task(workspace_id, agent_id, status, gmt_create)`
- `sophic_agent_execution_step(task_id, step_no)`
- `sophic_agent_invoke_log(workspace_id, task_id, gmt_create)`
- `sophic_agent_runtime_metric(workspace_id, metric_name, collect_time)`
- `sophic_agent_knowledge_document(workspace_id, kb_id, index_status, status)`
- `sophic_agent_datasource_field(workspace_id, datasource_id, table_id)`
- `sophic_agent_memory_long_term(workspace_id, memory_library_id, user_id, status, gmt_create)`
- `sophic_agent_publish_record(workspace_id, asset_type, asset_id, status)`
- `sophic_agent_eval_task(workspace_id, target_type, target_id, status)`
- `sophic_agent_session(workspace_id, agent_id, account_id, gmt_last_active)`
- `sophic_agent_agent_recent_visit(workspace_id, account_id, gmt_last_visit)`
- `sophic_agent_guardrail_record(workspace_id, rule_id, gmt_create)`

## 9. 最终结论

- 你现在的数据库设计主方向是对的，但账号权限域应继续沿用现有权限与认证服务，不应切到当前代码中的另一套账号模型。
- 但若严格对照《功能设计与复用映射》，当前数据库设计仍缺少“会话、收藏/最近访问/反馈、干预规则、MCP 实例、记忆实体/验证”这几类表。
- 因此结论是：当前设计可以支撑主链路能力上线，但还不能完全覆盖全部功能需求；补齐第 5 节建议表后，设计会更完整。
