-- SophicAgent V1 schema
-- MySQL 8.x

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- =========================================================
-- A. Identity / Workspace / RBAC
-- =========================================================

DROP TABLE IF EXISTS `sa_account`;
CREATE TABLE `sa_account` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `account_id` VARCHAR(64) NOT NULL,
  `username` VARCHAR(128) NOT NULL,
  `email` VARCHAR(255) DEFAULT NULL,
  `mobile` VARCHAR(64) DEFAULT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `nickname` VARCHAR(128) DEFAULT NULL,
  `avatar` VARCHAR(255) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_last_login` DATETIME DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_account_id` (`account_id`),
  UNIQUE KEY `uk_username` (`username`),
  KEY `idx_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='账户';

DROP TABLE IF EXISTS `sa_workspace`;
CREATE TABLE `sa_workspace` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `description` VARCHAR(1024) DEFAULT NULL,
  `owner_account_id` VARCHAR(64) NOT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `config` JSON DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_workspace_id` (`workspace_id`),
  KEY `idx_owner_account` (`owner_account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='工作空间';

DROP TABLE IF EXISTS `sa_api_key`;
CREATE TABLE `sa_api_key` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `account_id` VARCHAR(64) NOT NULL,
  `api_key` VARCHAR(512) NOT NULL,
  `description` VARCHAR(1024) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `expired_at` DATETIME DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_api_key` (`api_key`),
  KEY `idx_workspace_account` (`workspace_id`, `account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='API Key';

DROP TABLE IF EXISTS `sa_role`;
CREATE TABLE `sa_role` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `role_code` VARCHAR(64) NOT NULL,
  `role_name` VARCHAR(128) NOT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_workspace_role` (`workspace_id`, `role_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='角色';

DROP TABLE IF EXISTS `sa_permission`;
CREATE TABLE `sa_permission` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `perm_code` VARCHAR(128) NOT NULL,
  `perm_name` VARCHAR(128) NOT NULL,
  `resource_type` VARCHAR(64) NOT NULL,
  `action` VARCHAR(64) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_perm_code` (`perm_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='权限点';

DROP TABLE IF EXISTS `sa_role_permission`;
CREATE TABLE `sa_role_permission` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `role_code` VARCHAR(64) NOT NULL,
  `perm_code` VARCHAR(128) NOT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_role_perm` (`workspace_id`, `role_code`, `perm_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='角色权限';

DROP TABLE IF EXISTS `sa_account_role`;
CREATE TABLE `sa_account_role` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `account_id` VARCHAR(64) NOT NULL,
  `role_code` VARCHAR(64) NOT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_account_role` (`workspace_id`, `account_id`, `role_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户角色';

-- =========================================================
-- B. Agent + Designer
-- =========================================================

DROP TABLE IF EXISTS `sa_agent`;
CREATE TABLE `sa_agent` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `agent_id` VARCHAR(64) NOT NULL,
  `agent_code` VARCHAR(128) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `description` VARCHAR(1024) DEFAULT NULL,
  `agent_scope` VARCHAR(32) NOT NULL COMMENT 'COMMON/SCENE',
  `scene_type` VARCHAR(64) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `latest_version` VARCHAR(32) DEFAULT NULL,
  `tags` VARCHAR(512) DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_agent_id` (`agent_id`),
  UNIQUE KEY `uk_agent_code` (`workspace_id`, `agent_code`),
  KEY `idx_workspace_scope_status` (`workspace_id`, `agent_scope`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='智能体';

DROP TABLE IF EXISTS `sa_agent_version`;
CREATE TABLE `sa_agent_version` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `agent_id` VARCHAR(64) NOT NULL,
  `version` VARCHAR(32) NOT NULL,
  `version_desc` VARCHAR(1024) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `config_snapshot` JSON NOT NULL,
  `workflow_definition_id` VARCHAR(64) DEFAULT NULL,
  `runtime_config` JSON DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_agent_version` (`agent_id`, `version`),
  KEY `idx_workspace_agent` (`workspace_id`, `agent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='智能体版本';

DROP TABLE IF EXISTS `sa_model_provider`;
CREATE TABLE `sa_model_provider` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `provider_code` VARCHAR(64) NOT NULL,
  `name` VARCHAR(128) NOT NULL,
  `protocol` VARCHAR(32) NOT NULL DEFAULT 'OPENAI',
  `credential` JSON DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_provider` (`workspace_id`, `provider_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='模型供应商';

DROP TABLE IF EXISTS `sa_model`;
CREATE TABLE `sa_model` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `model_code` VARCHAR(64) NOT NULL,
  `provider_code` VARCHAR(64) NOT NULL,
  `model_name` VARCHAR(128) NOT NULL,
  `model_type` VARCHAR(64) NOT NULL COMMENT 'LLM/EMBEDDING/RERANK',
  `mode` VARCHAR(32) DEFAULT 'chat',
  `model_params` JSON DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_model_code` (`workspace_id`, `model_code`),
  KEY `idx_workspace_provider` (`workspace_id`, `provider_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='模型';

DROP TABLE IF EXISTS `sa_workflow_definition`;
CREATE TABLE `sa_workflow_definition` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `definition_id` VARCHAR(64) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `description` VARCHAR(1024) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `latest_version` VARCHAR(32) DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_definition_id` (`definition_id`),
  KEY `idx_workspace_status` (`workspace_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='工作流定义';

DROP TABLE IF EXISTS `sa_workflow_version`;
CREATE TABLE `sa_workflow_version` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `definition_id` VARCHAR(64) NOT NULL,
  `version` VARCHAR(32) NOT NULL,
  `version_desc` VARCHAR(1024) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `definition_snapshot` JSON NOT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_flow_version` (`definition_id`, `version`),
  KEY `idx_workspace_definition` (`workspace_id`, `definition_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='工作流版本';

DROP TABLE IF EXISTS `sa_workflow_node`;
CREATE TABLE `sa_workflow_node` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `definition_id` VARCHAR(64) NOT NULL,
  `version` VARCHAR(32) NOT NULL,
  `node_id` VARCHAR(64) NOT NULL,
  `node_type` VARCHAR(64) NOT NULL,
  `node_name` VARCHAR(255) NOT NULL,
  `node_config` JSON DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_node` (`definition_id`, `version`, `node_id`),
  KEY `idx_workspace_flow_ver` (`workspace_id`, `definition_id`, `version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='工作流节点';

DROP TABLE IF EXISTS `sa_workflow_edge`;
CREATE TABLE `sa_workflow_edge` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `definition_id` VARCHAR(64) NOT NULL,
  `version` VARCHAR(32) NOT NULL,
  `source_node_id` VARCHAR(64) NOT NULL,
  `target_node_id` VARCHAR(64) NOT NULL,
  `source_handle` VARCHAR(128) DEFAULT NULL,
  `target_handle` VARCHAR(128) DEFAULT NULL,
  `edge_config` JSON DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_workspace_flow_ver` (`workspace_id`, `definition_id`, `version`),
  KEY `idx_source_target` (`source_node_id`, `target_node_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='工作流连线';

DROP TABLE IF EXISTS `sa_agent_binding`;
CREATE TABLE `sa_agent_binding` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `agent_id` VARCHAR(64) NOT NULL,
  `agent_version` VARCHAR(32) NOT NULL,
  `binding_type` VARCHAR(32) NOT NULL COMMENT 'MODEL/KNOWLEDGE/TOOL/MEMORY',
  `target_code` VARCHAR(128) NOT NULL,
  `binding_config` JSON DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_workspace_agent_ver` (`workspace_id`, `agent_id`, `agent_version`),
  KEY `idx_binding_type_target` (`binding_type`, `target_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='智能体绑定关系';

-- =========================================================
-- C. Runtime
-- =========================================================

DROP TABLE IF EXISTS `sa_runtime_event`;
CREATE TABLE `sa_runtime_event` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `event_id` VARCHAR(64) NOT NULL,
  `event_type` VARCHAR(64) NOT NULL,
  `source_system` VARCHAR(128) DEFAULT NULL,
  `payload` JSON NOT NULL,
  `authorized` TINYINT NOT NULL DEFAULT 1,
  `route_agent_id` VARCHAR(64) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_event_id` (`event_id`),
  KEY `idx_workspace_event_status` (`workspace_id`, `event_type`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='运行时事件';

DROP TABLE IF EXISTS `sa_task`;
CREATE TABLE `sa_task` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `task_id` VARCHAR(64) NOT NULL,
  `conversation_id` VARCHAR(64) DEFAULT NULL,
  `agent_id` VARCHAR(64) NOT NULL,
  `agent_version` VARCHAR(32) DEFAULT NULL,
  `task_type` VARCHAR(64) NOT NULL COMMENT 'CHAT/WORKFLOW/ASYNC',
  `trigger_event_id` VARCHAR(64) DEFAULT NULL,
  `priority` INT NOT NULL DEFAULT 5,
  `status` TINYINT NOT NULL DEFAULT 1,
  `progress` INT NOT NULL DEFAULT 0,
  `input_payload` JSON DEFAULT NULL,
  `output_payload` JSON DEFAULT NULL,
  `error_code` VARCHAR(64) DEFAULT NULL,
  `error_message` VARCHAR(2000) DEFAULT NULL,
  `gmt_start` DATETIME DEFAULT NULL,
  `gmt_end` DATETIME DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_task_id` (`task_id`),
  KEY `idx_task_query` (`workspace_id`, `agent_id`, `status`, `gmt_create`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='任务主表';

DROP TABLE IF EXISTS `sa_execution_plan`;
CREATE TABLE `sa_execution_plan` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `task_id` VARCHAR(64) NOT NULL,
  `plan_id` VARCHAR(64) NOT NULL,
  `plan_content` JSON NOT NULL,
  `decision_policy` JSON DEFAULT NULL,
  `risk_review` JSON DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_plan_id` (`plan_id`),
  KEY `idx_workspace_task` (`workspace_id`, `task_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='执行计划';

DROP TABLE IF EXISTS `sa_execution_step`;
CREATE TABLE `sa_execution_step` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `task_id` VARCHAR(64) NOT NULL,
  `plan_id` VARCHAR(64) NOT NULL,
  `step_no` INT NOT NULL,
  `step_id` VARCHAR(64) NOT NULL,
  `step_type` VARCHAR(64) NOT NULL,
  `step_name` VARCHAR(255) DEFAULT NULL,
  `step_input` JSON DEFAULT NULL,
  `step_output` JSON DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `error_code` VARCHAR(64) DEFAULT NULL,
  `error_message` VARCHAR(2000) DEFAULT NULL,
  `cost_ms` BIGINT DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_task_step` (`task_id`, `step_id`),
  KEY `idx_task_step_no` (`task_id`, `step_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='执行步骤';

DROP TABLE IF EXISTS `sa_task_queue`;
CREATE TABLE `sa_task_queue` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `queue_name` VARCHAR(64) NOT NULL,
  `task_id` VARCHAR(64) NOT NULL,
  `priority` INT NOT NULL DEFAULT 5,
  `scheduler_node` VARCHAR(128) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_schedule` DATETIME DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_queue` (`workspace_id`, `queue_name`, `status`, `priority`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='调度队列';

-- =========================================================
-- D. Capability center
-- =========================================================

DROP TABLE IF EXISTS `sa_knowledge_base`;
CREATE TABLE `sa_knowledge_base` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `kb_id` VARCHAR(64) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `description` VARCHAR(1024) DEFAULT NULL,
  `kb_type` VARCHAR(64) NOT NULL DEFAULT 'UNSTRUCTURED',
  `process_config` JSON DEFAULT NULL,
  `index_config` JSON DEFAULT NULL,
  `search_config` JSON DEFAULT NULL,
  `permission_scope` VARCHAR(64) DEFAULT 'WORKSPACE',
  `status` TINYINT NOT NULL DEFAULT 1,
  `total_docs` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_kb_id` (`kb_id`),
  KEY `idx_kb_status` (`workspace_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='知识库';

DROP TABLE IF EXISTS `sa_knowledge_document`;
CREATE TABLE `sa_knowledge_document` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `kb_id` VARCHAR(64) NOT NULL,
  `doc_id` VARCHAR(64) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `doc_type` VARCHAR(64) NOT NULL,
  `format` VARCHAR(32) DEFAULT NULL,
  `source` VARCHAR(255) DEFAULT NULL,
  `metadata` JSON DEFAULT NULL,
  `index_status` TINYINT NOT NULL DEFAULT 1,
  `enabled` TINYINT NOT NULL DEFAULT 1,
  `status` TINYINT NOT NULL DEFAULT 1,
  `error_msg` VARCHAR(2000) DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_doc_id` (`doc_id`),
  KEY `idx_doc_query` (`workspace_id`, `kb_id`, `index_status`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='知识文档';

DROP TABLE IF EXISTS `sa_knowledge_chunk`;
CREATE TABLE `sa_knowledge_chunk` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `kb_id` VARCHAR(64) NOT NULL,
  `doc_id` VARCHAR(64) NOT NULL,
  `chunk_id` VARCHAR(64) NOT NULL,
  `content` LONGTEXT NOT NULL,
  `metadata` JSON DEFAULT NULL,
  `vector_id` VARCHAR(128) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_chunk_id` (`chunk_id`),
  KEY `idx_chunk_query` (`workspace_id`, `kb_id`, `doc_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='知识分片';

DROP TABLE IF EXISTS `sa_tool`;
CREATE TABLE `sa_tool` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `tool_id` VARCHAR(64) NOT NULL,
  `tool_code` VARCHAR(128) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `description` VARCHAR(1024) DEFAULT NULL,
  `tool_type` VARCHAR(64) NOT NULL,
  `source` VARCHAR(64) DEFAULT 'CUSTOM',
  `api_schema` JSON DEFAULT NULL,
  `config` JSON DEFAULT NULL,
  `enabled` TINYINT NOT NULL DEFAULT 1,
  `status` TINYINT NOT NULL DEFAULT 1,
  `latest_version` VARCHAR(32) DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tool_id` (`tool_id`),
  UNIQUE KEY `uk_tool_code` (`workspace_id`, `tool_code`),
  KEY `idx_tool_status` (`workspace_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='工具';

DROP TABLE IF EXISTS `sa_tool_version`;
CREATE TABLE `sa_tool_version` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `tool_id` VARCHAR(64) NOT NULL,
  `version` VARCHAR(32) NOT NULL,
  `version_desc` VARCHAR(1024) DEFAULT NULL,
  `schema_snapshot` JSON NOT NULL,
  `config_snapshot` JSON DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tool_version` (`tool_id`, `version`),
  KEY `idx_workspace_tool` (`workspace_id`, `tool_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='工具版本';

DROP TABLE IF EXISTS `sa_tool_debug_record`;
CREATE TABLE `sa_tool_debug_record` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `tool_id` VARCHAR(64) NOT NULL,
  `request_payload` JSON DEFAULT NULL,
  `response_payload` JSON DEFAULT NULL,
  `success` TINYINT NOT NULL DEFAULT 0,
  `error_message` VARCHAR(2000) DEFAULT NULL,
  `cost_ms` BIGINT DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_tool_debug` (`workspace_id`, `tool_id`, `gmt_create`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='工具调试记录';

DROP TABLE IF EXISTS `sa_mcp_server`;
CREATE TABLE `sa_mcp_server` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `server_code` VARCHAR(64) NOT NULL,
  `name` VARCHAR(128) NOT NULL,
  `description` VARCHAR(1024) DEFAULT NULL,
  `server_type` VARCHAR(32) NOT NULL,
  `install_type` VARCHAR(32) DEFAULT NULL,
  `host` VARCHAR(1024) DEFAULT NULL,
  `deploy_config` JSON DEFAULT NULL,
  `detail_config` JSON DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_mcp_server` (`workspace_id`, `server_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='MCP服务';

DROP TABLE IF EXISTS `sa_memory_short_term`;
CREATE TABLE `sa_memory_short_term` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `session_id` VARCHAR(64) NOT NULL,
  `seq_no` BIGINT NOT NULL,
  `role` VARCHAR(32) NOT NULL,
  `content` LONGTEXT NOT NULL,
  `metadata` JSON DEFAULT NULL,
  `expired_at` DATETIME DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_session_seq` (`workspace_id`, `session_id`, `seq_no`),
  KEY `idx_expired_at` (`expired_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='短期记忆';

DROP TABLE IF EXISTS `sa_memory_working`;
CREATE TABLE `sa_memory_working` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `task_id` VARCHAR(64) NOT NULL,
  `memory_key` VARCHAR(128) NOT NULL,
  `memory_value` JSON DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_task_memory_key` (`task_id`, `memory_key`),
  KEY `idx_workspace_task` (`workspace_id`, `task_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='工作记忆';

-- =========================================================
-- E. Governance / Observability
-- =========================================================

DROP TABLE IF EXISTS `sa_invoke_log`;
CREATE TABLE `sa_invoke_log` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `trace_id` VARCHAR(64) DEFAULT NULL,
  `request_id` VARCHAR(64) DEFAULT NULL,
  `task_id` VARCHAR(64) DEFAULT NULL,
  `agent_id` VARCHAR(64) DEFAULT NULL,
  `invoke_type` VARCHAR(64) NOT NULL,
  `target_code` VARCHAR(128) DEFAULT NULL,
  `input_digest` TEXT DEFAULT NULL,
  `output_digest` TEXT DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `error_code` VARCHAR(64) DEFAULT NULL,
  `error_message` VARCHAR(2000) DEFAULT NULL,
  `cost_ms` BIGINT DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_invoke_query` (`workspace_id`, `task_id`, `gmt_create`),
  KEY `idx_trace` (`trace_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='调用日志';

DROP TABLE IF EXISTS `sa_audit_event`;
CREATE TABLE `sa_audit_event` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `audit_id` VARCHAR(64) NOT NULL,
  `operator_id` VARCHAR(64) DEFAULT NULL,
  `event_type` VARCHAR(64) NOT NULL,
  `resource_type` VARCHAR(64) DEFAULT NULL,
  `resource_code` VARCHAR(128) DEFAULT NULL,
  `action` VARCHAR(64) NOT NULL,
  `result` VARCHAR(32) NOT NULL,
  `detail` JSON DEFAULT NULL,
  `trace_id` VARCHAR(64) DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_audit_id` (`audit_id`),
  KEY `idx_audit_query` (`workspace_id`, `event_type`, `gmt_create`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='审计事件';

DROP TABLE IF EXISTS `sa_runtime_metric`;
CREATE TABLE `sa_runtime_metric` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `metric_scope` VARCHAR(64) NOT NULL,
  `metric_name` VARCHAR(128) NOT NULL,
  `metric_value` DECIMAL(20, 6) NOT NULL,
  `metric_tags` JSON DEFAULT NULL,
  `collect_time` DATETIME NOT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_metric_query` (`workspace_id`, `metric_name`, `collect_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='运行指标';

DROP TABLE IF EXISTS `sa_alarm_rule`;
CREATE TABLE `sa_alarm_rule` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `rule_code` VARCHAR(64) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `metric_name` VARCHAR(128) NOT NULL,
  `expr` VARCHAR(1024) NOT NULL,
  `severity` VARCHAR(32) NOT NULL,
  `enabled` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_alarm_rule` (`workspace_id`, `rule_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='告警规则';

DROP TABLE IF EXISTS `sa_alarm_record`;
CREATE TABLE `sa_alarm_record` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `alarm_id` VARCHAR(64) NOT NULL,
  `rule_code` VARCHAR(64) NOT NULL,
  `metric_name` VARCHAR(128) NOT NULL,
  `trigger_value` DECIMAL(20, 6) NOT NULL,
  `severity` VARCHAR(32) NOT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `detail` JSON DEFAULT NULL,
  `trigger_time` DATETIME NOT NULL,
  `recover_time` DATETIME DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_alarm_id` (`alarm_id`),
  KEY `idx_alarm_query` (`workspace_id`, `rule_code`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='告警记录';

DROP TABLE IF EXISTS `sa_fault_record`;
CREATE TABLE `sa_fault_record` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `fault_id` VARCHAR(64) NOT NULL,
  `task_id` VARCHAR(64) DEFAULT NULL,
  `source_type` VARCHAR(64) NOT NULL,
  `source_code` VARCHAR(128) DEFAULT NULL,
  `fault_type` VARCHAR(64) NOT NULL,
  `severity` VARCHAR(32) NOT NULL,
  `error_code` VARCHAR(64) DEFAULT NULL,
  `error_message` VARCHAR(2000) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_fault_id` (`fault_id`),
  KEY `idx_fault_query` (`workspace_id`, `status`, `gmt_create`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='故障记录';

DROP TABLE IF EXISTS `sa_fault_process_record`;
CREATE TABLE `sa_fault_process_record` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `fault_id` VARCHAR(64) NOT NULL,
  `action_type` VARCHAR(64) NOT NULL,
  `action_detail` JSON DEFAULT NULL,
  `result` VARCHAR(32) NOT NULL,
  `operator_id` VARCHAR(64) DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_fault_process` (`workspace_id`, `fault_id`, `gmt_create`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='故障处理记录';

SET FOREIGN_KEY_CHECKS = 1;
