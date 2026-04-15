-- SophicAgent V1 schema
-- MySQL 8.x

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- =========================================================
-- A. Identity / Workspace / RBAC
-- =========================================================

DROP TABLE IF EXISTS `sophic_agent_account`;
CREATE TABLE `sophic_agent_account` (
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

DROP TABLE IF EXISTS `sophic_agent_workspace`;
CREATE TABLE `sophic_agent_workspace` (
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

DROP TABLE IF EXISTS `sophic_agent_api_key`;
CREATE TABLE `sophic_agent_api_key` (
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

DROP TABLE IF EXISTS `sophic_agent_role`;
CREATE TABLE `sophic_agent_role` (
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

DROP TABLE IF EXISTS `sophic_agent_permission`;
CREATE TABLE `sophic_agent_permission` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `perm_code` VARCHAR(128) NOT NULL,
  `perm_name` VARCHAR(128) NOT NULL,
  `resource_type` VARCHAR(64) NOT NULL,
  `action` VARCHAR(64) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_perm_code` (`perm_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='权限点';

DROP TABLE IF EXISTS `sophic_agent_role_permission`;
CREATE TABLE `sophic_agent_role_permission` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `role_code` VARCHAR(64) NOT NULL,
  `perm_code` VARCHAR(128) NOT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_role_perm` (`workspace_id`, `role_code`, `perm_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='角色权限';

DROP TABLE IF EXISTS `sophic_agent_account_role`;
CREATE TABLE `sophic_agent_account_role` (
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

DROP TABLE IF EXISTS `sophic_agent_application`;
CREATE TABLE `sophic_agent_application` (
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

DROP TABLE IF EXISTS `sophic_agent_application_version`;
CREATE TABLE `sophic_agent_application_version` (
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

DROP TABLE IF EXISTS `sophic_agent_high_code_service`;
CREATE TABLE `sophic_agent_high_code_service` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `service_id` VARCHAR(64) NOT NULL,
  `service_code` VARCHAR(128) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `description` VARCHAR(1024) DEFAULT NULL,
  `service_type` VARCHAR(32) NOT NULL COMMENT 'JAVA/PYTHON',
  `runtime_type` VARCHAR(32) DEFAULT NULL COMMENT 'SPRING_BOOT/FASTAPI/FLASK/OTHER',
  `owner_account_id` VARCHAR(64) DEFAULT NULL,
  `permission_scope` VARCHAR(32) NOT NULL DEFAULT 'PRIVATE',
  `status` TINYINT NOT NULL DEFAULT 1,
  `latest_version` VARCHAR(32) DEFAULT NULL,
  `tags` VARCHAR(512) DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_service_id` (`service_id`),
  UNIQUE KEY `uk_workspace_service_code` (`workspace_id`, `service_code`),
  KEY `idx_service_query` (`workspace_id`, `service_type`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='高代码服务';

DROP TABLE IF EXISTS `sophic_agent_high_code_service_version`;
CREATE TABLE `sophic_agent_high_code_service_version` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `service_id` VARCHAR(64) NOT NULL,
  `version` VARCHAR(32) NOT NULL,
  `version_desc` VARCHAR(1024) DEFAULT NULL,
  `package_type` VARCHAR(32) NOT NULL COMMENT 'JAR/DOCKER',
  `package_uri` VARCHAR(1024) DEFAULT NULL,
  `deploy_config` JSON DEFAULT NULL,
  `input_schema` JSON DEFAULT NULL,
  `output_schema` JSON DEFAULT NULL,
  `change_log` JSON DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_service_version` (`service_id`, `version`),
  KEY `idx_service_version_query` (`workspace_id`, `service_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='高代码服务版本';

DROP TABLE IF EXISTS `sophic_agent_model_provider`;
CREATE TABLE `sophic_agent_model_provider` (
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

DROP TABLE IF EXISTS `sophic_agent_model`;
CREATE TABLE `sophic_agent_model` (
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

DROP TABLE IF EXISTS `sophic_agent_workflow_definition`;
CREATE TABLE `sophic_agent_workflow_definition` (
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

DROP TABLE IF EXISTS `sophic_agent_workflow_version`;
CREATE TABLE `sophic_agent_workflow_version` (
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

DROP TABLE IF EXISTS `sophic_agent_workflow_node`;
CREATE TABLE `sophic_agent_workflow_node` (
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

DROP TABLE IF EXISTS `sophic_agent_workflow_edge`;
CREATE TABLE `sophic_agent_workflow_edge` (
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

DROP TABLE IF EXISTS `sophic_agent_application_binding`;
CREATE TABLE `sophic_agent_application_binding` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `agent_id` VARCHAR(64) NOT NULL,
  `agent_version` VARCHAR(32) NOT NULL,
  `resource_type` VARCHAR(32) NOT NULL COMMENT 'MODEL/KNOWLEDGE_BASE/TOOL/MEMORY_LIBRARY/DATASOURCE/MCP_SERVER/AGENT/WORKFLOW/HIGH_CODE_SERVICE',
  `resource_id` VARCHAR(64) NOT NULL,
  `resource_name` VARCHAR(255) DEFAULT NULL,
  `binding_source` VARCHAR(32) NOT NULL DEFAULT 'DESIGNER' COMMENT 'DESIGNER/PUBLISH/RUNTIME',
  `sort_no` INT DEFAULT NULL,
  `enabled` TINYINT NOT NULL DEFAULT 1,
  `binding_config` JSON DEFAULT NULL,
  `selector_config` JSON DEFAULT NULL COMMENT '选中的MCP工具/数据表/概念等范围',
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_agent_resource_binding` (`agent_id`, `agent_version`, `resource_type`, `resource_id`),
  KEY `idx_workspace_agent_ver` (`workspace_id`, `agent_id`, `agent_version`),
  KEY `idx_binding_resource` (`workspace_id`, `resource_type`, `resource_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='智能体资源绑定关系';

DROP TABLE IF EXISTS `sophic_agent_application_binding_item`;
CREATE TABLE `sophic_agent_application_binding_item` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `binding_id` BIGINT UNSIGNED NOT NULL,
  `item_type` VARCHAR(32) NOT NULL COMMENT 'MCP_TOOL/TABLE/FIELD/CONCEPT/ATTRIBUTE/WORKFLOW_NODE',
  `item_id` VARCHAR(64) NOT NULL,
  `item_name` VARCHAR(255) DEFAULT NULL,
  `item_config` JSON DEFAULT NULL,
  `sort_no` INT DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_binding_item` (`binding_id`, `item_type`, `item_id`),
  KEY `idx_binding_item_query` (`workspace_id`, `binding_id`, `item_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='智能体资源绑定明细';

-- =========================================================
-- C. Runtime
-- =========================================================

DROP TABLE IF EXISTS `sophic_agent_runtime_event`;
CREATE TABLE `sophic_agent_runtime_event` (
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

DROP TABLE IF EXISTS `sophic_agent_task`;
CREATE TABLE `sophic_agent_task` (
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

DROP TABLE IF EXISTS `sophic_agent_execution_plan`;
CREATE TABLE `sophic_agent_execution_plan` (
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

DROP TABLE IF EXISTS `sophic_agent_execution_step`;
CREATE TABLE `sophic_agent_execution_step` (
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

DROP TABLE IF EXISTS `sophic_agent_task_queue`;
CREATE TABLE `sophic_agent_task_queue` (
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

DROP TABLE IF EXISTS `sophic_agent_knowledge_base`;
CREATE TABLE `sophic_agent_knowledge_base` (
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

DROP TABLE IF EXISTS `sophic_agent_resource`;
CREATE TABLE `sophic_agent_resource` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `resource_id` VARCHAR(64) NOT NULL,
  `resource_name` VARCHAR(128) NOT NULL,
  `resource_type` VARCHAR(32) NOT NULL COMMENT 'KNOWLEDGE_BASE/TOOL/MCP_SERVER/DATASOURCE/MEMORY_LIBRARY/AGENT/WORKFLOW/HIGH_CODE_SERVICE',
  `source_system` VARCHAR(64) DEFAULT NULL COMMENT 'LOCAL/DIFY/NACOS/EXTERNAL',
  `resource_code` VARCHAR(128) DEFAULT NULL,
  `owner_account_id` VARCHAR(64) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `description` VARCHAR(1024) DEFAULT NULL,
  `ext_config` JSON DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_workspace_resource` (`workspace_id`, `resource_type`, `resource_id`),
  KEY `idx_resource_query` (`workspace_id`, `resource_type`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='统一资源表';

DROP TABLE IF EXISTS `sophic_agent_knowledge_document`;
CREATE TABLE `sophic_agent_knowledge_document` (
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

DROP TABLE IF EXISTS `sophic_agent_knowledge_chunk`;
CREATE TABLE `sophic_agent_knowledge_chunk` (
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

DROP TABLE IF EXISTS `sophic_agent_tool`;
CREATE TABLE `sophic_agent_tool` (
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

DROP TABLE IF EXISTS `sophic_agent_tool_version`;
CREATE TABLE `sophic_agent_tool_version` (
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

DROP TABLE IF EXISTS `sophic_agent_tool_debug_record`;
CREATE TABLE `sophic_agent_tool_debug_record` (
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

DROP TABLE IF EXISTS `sophic_agent_mcp_server`;
CREATE TABLE `sophic_agent_mcp_server` (
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

DROP TABLE IF EXISTS `sophic_agent_memory_short_term`;
CREATE TABLE `sophic_agent_memory_short_term` (
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

DROP TABLE IF EXISTS `sophic_agent_memory_working`;
CREATE TABLE `sophic_agent_memory_working` (
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

DROP TABLE IF EXISTS `sophic_agent_datasource`;
CREATE TABLE `sophic_agent_datasource` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `datasource_id` VARCHAR(64) NOT NULL,
  `datasource_code` VARCHAR(128) DEFAULT NULL,
  `datasource_name` VARCHAR(128) NOT NULL,
  `schema_type` VARCHAR(32) NOT NULL COMMENT 'RELATIONAL/UNIFIED_MODEL/SOPHIC',
  `datasource_type` VARCHAR(64) DEFAULT NULL COMMENT 'MYSQL/POSTGRESQL/ORACLE/API/OTHER',
  `host` VARCHAR(256) DEFAULT NULL,
  `port` INT DEFAULT NULL,
  `database_name` VARCHAR(128) DEFAULT NULL,
  `username` VARCHAR(128) DEFAULT NULL,
  `password_cipher` VARCHAR(512) DEFAULT NULL,
  `connection_url` VARCHAR(512) DEFAULT NULL,
  `owner_account_id` VARCHAR(64) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `description` VARCHAR(1024) DEFAULT NULL,
  `connect_config` JSON DEFAULT NULL,
  `gmt_last_sync` DATETIME DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_datasource_id` (`datasource_id`),
  UNIQUE KEY `uk_workspace_datasource_code` (`workspace_id`, `datasource_code`),
  KEY `idx_datasource_name` (`workspace_id`, `datasource_name`),
  KEY `idx_schema_type_datasource_type` (`workspace_id`, `schema_type`, `datasource_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='数据源';

DROP TABLE IF EXISTS `sophic_agent_datasource_table`;
CREATE TABLE `sophic_agent_datasource_table` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `datasource_id` VARCHAR(64) NOT NULL,
  `table_id` VARCHAR(64) NOT NULL,
  `schema_name` VARCHAR(128) DEFAULT NULL,
  `table_name` VARCHAR(128) NOT NULL,
  `table_comment` VARCHAR(512) DEFAULT NULL,
  `refresh_version` VARCHAR(64) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `is_deleted` TINYINT NOT NULL DEFAULT 0,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_datasource_schema_table` (`datasource_id`, `schema_name`, `table_name`),
  UNIQUE KEY `uk_table_id` (`table_id`),
  KEY `idx_datasource_table` (`workspace_id`, `datasource_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='数据源表信息';

DROP TABLE IF EXISTS `sophic_agent_datasource_field`;
CREATE TABLE `sophic_agent_datasource_field` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `datasource_id` VARCHAR(64) NOT NULL,
  `table_id` VARCHAR(64) NOT NULL,
  `field_id` VARCHAR(64) NOT NULL,
  `table_name` VARCHAR(128) DEFAULT NULL,
  `column_name` VARCHAR(128) NOT NULL,
  `column_comment` VARCHAR(512) DEFAULT NULL,
  `data_type` VARCHAR(128) DEFAULT NULL,
  `is_primary` TINYINT DEFAULT 0,
  `is_foreign` TINYINT DEFAULT 0,
  `is_not_null` TINYINT DEFAULT 0,
  `field_status` VARCHAR(16) DEFAULT NULL,
  `refresh_version` VARCHAR(64) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `is_deleted` TINYINT NOT NULL DEFAULT 0,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_field_id` (`field_id`),
  UNIQUE KEY `uk_table_column` (`table_id`, `column_name`),
  KEY `idx_field_datasource_table` (`workspace_id`, `datasource_id`, `table_id`),
  KEY `idx_field_status` (`workspace_id`, `field_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='数据源字段信息';

DROP TABLE IF EXISTS `sophic_agent_datasource_relation`;
CREATE TABLE `sophic_agent_datasource_relation` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `datasource_id` VARCHAR(64) NOT NULL,
  `relation_id` VARCHAR(64) NOT NULL,
  `source_table_id` VARCHAR(64) DEFAULT NULL,
  `source_name` VARCHAR(128) NOT NULL,
  `source_field_name` VARCHAR(128) NOT NULL,
  `target_table_id` VARCHAR(64) DEFAULT NULL,
  `target_name` VARCHAR(128) NOT NULL,
  `target_field_name` VARCHAR(128) NOT NULL,
  `relation_type` VARCHAR(16) DEFAULT NULL,
  `description` VARCHAR(512) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_relation_id` (`relation_id`),
  UNIQUE KEY `uk_datasource_relation` (`datasource_id`, `source_name`, `source_field_name`, `target_name`, `target_field_name`),
  KEY `idx_relation_source` (`workspace_id`, `datasource_id`, `source_table_id`),
  KEY `idx_relation_target` (`workspace_id`, `datasource_id`, `target_table_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='数据源逻辑关系';

DROP TABLE IF EXISTS `sophic_agent_datasource_semantic_model`;
CREATE TABLE `sophic_agent_datasource_semantic_model` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `datasource_id` VARCHAR(64) NOT NULL,
  `semantic_id` VARCHAR(64) NOT NULL,
  `table_id` VARCHAR(64) NOT NULL,
  `field_id` VARCHAR(64) DEFAULT NULL,
  `semantic_level` VARCHAR(16) NOT NULL COMMENT 'TABLE/FIELD/CONCEPT',
  `model_name` VARCHAR(128) DEFAULT NULL,
  `field_name` VARCHAR(128) DEFAULT NULL,
  `business_name` VARCHAR(128) DEFAULT NULL,
  `synonyms` VARCHAR(512) DEFAULT NULL,
  `business_description` VARCHAR(1024) DEFAULT NULL,
  `metadata` JSON DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_semantic_id` (`semantic_id`),
  UNIQUE KEY `uk_semantic_target` (`datasource_id`, `table_id`, `field_id`, `semantic_level`),
  KEY `idx_semantic_datasource_level` (`workspace_id`, `datasource_id`, `semantic_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='数据源语义模型';

-- =========================================================
-- E. Governance / Observability
-- =========================================================

DROP TABLE IF EXISTS `sophic_agent_invoke_log`;
CREATE TABLE `sophic_agent_invoke_log` (
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

DROP TABLE IF EXISTS `sophic_agent_audit_event`;
CREATE TABLE `sophic_agent_audit_event` (
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

DROP TABLE IF EXISTS `sophic_agent_runtime_metric`;
CREATE TABLE `sophic_agent_runtime_metric` (
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

DROP TABLE IF EXISTS `sophic_agent_alarm_rule`;
CREATE TABLE `sophic_agent_alarm_rule` (
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

DROP TABLE IF EXISTS `sophic_agent_alarm_record`;
CREATE TABLE `sophic_agent_alarm_record` (
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

DROP TABLE IF EXISTS `sophic_agent_fault_record`;
CREATE TABLE `sophic_agent_fault_record` (
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

DROP TABLE IF EXISTS `sophic_agent_fault_process_record`;
CREATE TABLE `sophic_agent_fault_process_record` (
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
