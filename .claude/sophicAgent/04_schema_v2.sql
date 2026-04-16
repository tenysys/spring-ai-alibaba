-- SophicAgent V2 incremental schema
-- Run after 03_schema_v1.sql
-- Incremental schema follows the same primary key convention:
-- 1. New tables use `id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT` as physical primary key.
-- 2. Main business entities keep `xxx_id` as business identifier and optionally `xxx_code` as readable code.
-- 3. Relation/fact tables are not forced to add UUID business keys; use composite unique keys or indexes when needed.

SET NAMES utf8mb4;

-- =========================================================
-- Memory expansion
-- =========================================================

CREATE TABLE IF NOT EXISTS `sophic_agent_memory_long_term` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `memory_library_id` VARCHAR(64) DEFAULT NULL,
  `agent_id` VARCHAR(64) DEFAULT NULL,
  `user_id` VARCHAR(64) NOT NULL,
  `memory_id` VARCHAR(64) NOT NULL,
  `entity_id` VARCHAR(64) DEFAULT NULL,
  `session_id` VARCHAR(64) DEFAULT NULL,
  `content` LONGTEXT NOT NULL,
  `summary_content` LONGTEXT DEFAULT NULL,
  `memory_type` VARCHAR(32) NOT NULL DEFAULT 'FRAGMENT' COMMENT 'FRAGMENT/ENTITY/SUMMARY',
  `tags` VARCHAR(512) DEFAULT NULL,
  `rule_snapshot` JSON DEFAULT NULL,
  `metadata` JSON DEFAULT NULL,
  `embedding_ref` VARCHAR(128) DEFAULT NULL,
  `score` DECIMAL(6,4) DEFAULT NULL,
  `expired_at` DATETIME DEFAULT NULL,
  `hit_count` BIGINT NOT NULL DEFAULT 0,
  `last_hit_time` DATETIME DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_memory_id` (`memory_id`),
  KEY `idx_memory_query` (`workspace_id`, `memory_library_id`, `user_id`, `status`, `gmt_create`),
  KEY `idx_memory_entity` (`workspace_id`, `agent_id`, `entity_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='长期记忆';

CREATE TABLE IF NOT EXISTS `sophic_agent_memory_library` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `memory_library_id` VARCHAR(64) NOT NULL,
  `library_code` VARCHAR(128) DEFAULT NULL,
  `name` VARCHAR(255) NOT NULL,
  `description` VARCHAR(1024) DEFAULT NULL,
  `owner_account_id` VARCHAR(64) DEFAULT NULL,
  `default_rule_id` VARCHAR(64) DEFAULT NULL,
  `permission_scope` VARCHAR(32) NOT NULL DEFAULT 'PRIVATE',
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_memory_library_id` (`memory_library_id`),
  UNIQUE KEY `uk_memory_library_code` (`workspace_id`, `library_code`),
  KEY `idx_memory_library_query` (`workspace_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='记忆库';

CREATE TABLE IF NOT EXISTS `sophic_agent_memory_rule` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `rule_id` VARCHAR(64) NOT NULL,
  `memory_library_id` VARCHAR(64) NOT NULL,
  `rule_name` VARCHAR(255) NOT NULL,
  `extract_mode` VARCHAR(32) NOT NULL DEFAULT 'AI' COMMENT 'AI/RULE/MIXED',
  `expire_days` INT DEFAULT NULL,
  `rule_content` JSON NOT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_memory_rule_id` (`rule_id`),
  KEY `idx_memory_rule_query` (`workspace_id`, `memory_library_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='记忆规则';

CREATE TABLE IF NOT EXISTS `sophic_agent_memory_hit_record` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `hit_id` VARCHAR(64) NOT NULL,
  `memory_library_id` VARCHAR(64) NOT NULL,
  `memory_id` VARCHAR(64) NOT NULL,
  `task_id` VARCHAR(64) DEFAULT NULL,
  `query_text` VARCHAR(2000) DEFAULT NULL,
  `similarity_score` DECIMAL(6,4) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_memory_hit_id` (`hit_id`),
  KEY `idx_memory_hit_query` (`workspace_id`, `memory_library_id`, `memory_id`, `gmt_create`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='记忆命中记录';

-- =========================================================
-- Statistics
-- =========================================================

CREATE TABLE IF NOT EXISTS `sophic_agent_invoke_stat_daily` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `stat_date` DATE NOT NULL,
  `dim_type` VARCHAR(32) NOT NULL COMMENT 'USER/BUSINESS/MODEL/TOOL/AGENT',
  `dim_code` VARCHAR(128) NOT NULL,
  `invoke_count` BIGINT NOT NULL DEFAULT 0,
  `success_count` BIGINT NOT NULL DEFAULT 0,
  `fail_count` BIGINT NOT NULL DEFAULT 0,
  `avg_cost_ms` DECIMAL(20,4) DEFAULT NULL,
  `token_in` BIGINT DEFAULT NULL,
  `token_out` BIGINT DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_stat_dim` (`workspace_id`, `stat_date`, `dim_type`, `dim_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='调用日统计';

-- =========================================================
-- Concurrency control
-- =========================================================

CREATE TABLE IF NOT EXISTS `sophic_agent_traffic_limit_rule` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `rule_code` VARCHAR(64) NOT NULL,
  `scope` VARCHAR(64) NOT NULL COMMENT 'GLOBAL/AGENT/TOOL/APIKEY',
  `scope_code` VARCHAR(128) DEFAULT NULL,
  `qps_limit` INT DEFAULT NULL,
  `concurrency_limit` INT DEFAULT NULL,
  `burst_limit` INT DEFAULT NULL,
  `enabled` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_limit_rule` (`workspace_id`, `rule_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='限流规则';

CREATE TABLE IF NOT EXISTS `sophic_agent_concurrent_quota` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `resource_group` VARCHAR(128) NOT NULL,
  `quota_total` INT NOT NULL,
  `quota_used` INT NOT NULL DEFAULT 0,
  `enabled` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_resource_quota` (`workspace_id`, `resource_group`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='并发配额';

-- =========================================================
-- High availability
-- =========================================================

CREATE TABLE IF NOT EXISTS `sophic_agent_ha_node` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `node_id` VARCHAR(64) NOT NULL,
  `service_group` VARCHAR(128) NOT NULL,
  `node_role` VARCHAR(16) NOT NULL COMMENT 'ACTIVE/STANDBY',
  `health_status` VARCHAR(16) NOT NULL COMMENT 'UP/DOWN/DEGRADED',
  `resource_usage` JSON DEFAULT NULL,
  `gmt_last_heartbeat` DATETIME DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ha_node` (`workspace_id`, `node_id`),
  KEY `idx_service_group` (`workspace_id`, `service_group`, `health_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='高可用节点';

CREATE TABLE IF NOT EXISTS `sophic_agent_ha_switch_record` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `switch_id` VARCHAR(64) NOT NULL,
  `service_group` VARCHAR(128) NOT NULL,
  `from_node_id` VARCHAR(64) DEFAULT NULL,
  `to_node_id` VARCHAR(64) DEFAULT NULL,
  `trigger_reason` VARCHAR(1024) DEFAULT NULL,
  `result` VARCHAR(32) NOT NULL COMMENT 'SUCCESS/FAIL',
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_switch_id` (`switch_id`),
  KEY `idx_switch_query` (`workspace_id`, `service_group`, `gmt_create`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='主备切换记录';

-- =========================================================
-- Config, integration and deploy
-- =========================================================

CREATE TABLE IF NOT EXISTS `sophic_agent_runtime_config_history` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `config_key` VARCHAR(128) NOT NULL,
  `config_value` JSON DEFAULT NULL,
  `change_type` VARCHAR(32) NOT NULL COMMENT 'CREATE/UPDATE/DELETE',
  `operator_id` VARCHAR(64) DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_config_history` (`workspace_id`, `config_key`, `gmt_create`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='运行配置历史';

CREATE TABLE IF NOT EXISTS `sophic_agent_integration_endpoint` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `endpoint_id` VARCHAR(64) NOT NULL,
  `system_name` VARCHAR(255) NOT NULL,
  `endpoint_type` VARCHAR(32) NOT NULL COMMENT 'HTTP/RPC/MQ/MCP',
  `endpoint_url` VARCHAR(1024) DEFAULT NULL,
  `auth_config` JSON DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_endpoint_id` (`endpoint_id`),
  KEY `idx_endpoint_query` (`workspace_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='外部接入点';

CREATE TABLE IF NOT EXISTS `sophic_agent_integration_record` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `target_id` VARCHAR(64) NOT NULL COMMENT 'endpoint_id',
  `request_payload` JSON DEFAULT NULL,
  `response_payload` JSON DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '1-成功,2-失败',
  `error_message` VARCHAR(2000) DEFAULT NULL,
  `cost_ms` BIGINT DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_integration_record` (`workspace_id`, `target_id`, `gmt_create`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='集成调用记录';

CREATE TABLE IF NOT EXISTS `sophic_agent_deploy_plan` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `plan_id` VARCHAR(64) NOT NULL,
  `env` VARCHAR(64) NOT NULL COMMENT 'dev/test/prod',
  `plan_content` JSON NOT NULL,
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '1-待执行,2-执行中,3-成功,4-失败,5-回滚',
  `operator_id` VARCHAR(64) DEFAULT NULL,
  `gmt_start` DATETIME DEFAULT NULL,
  `gmt_end` DATETIME DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_plan_id` (`plan_id`),
  KEY `idx_deploy_query` (`workspace_id`, `env`, `status`, `gmt_create`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='部署计划';

-- =========================================================
-- Publish management
-- =========================================================

CREATE TABLE IF NOT EXISTS `sophic_agent_publish_record` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `publish_id` VARCHAR(64) NOT NULL,
  `asset_type` VARCHAR(32) NOT NULL COMMENT 'AGENT/WORKFLOW/TOOL/HIGH_CODE_SERVICE',
  `asset_id` VARCHAR(64) NOT NULL,
  `asset_version` VARCHAR(32) NOT NULL,
  `publish_type` VARCHAR(32) NOT NULL COMMENT 'APPLICATION/TOOL/API',
  `target_resource_id` VARCHAR(64) DEFAULT NULL,
  `input_schema` JSON DEFAULT NULL,
  `output_schema` JSON DEFAULT NULL,
  `config_snapshot` JSON DEFAULT NULL,
  `change_log` JSON DEFAULT NULL,
  `operator_id` VARCHAR(64) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '1-DRAFT,2-PUBLISHED,3-OFFLINE,4-DELETED',
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_publish_id` (`publish_id`),
  KEY `idx_publish_query` (`workspace_id`, `asset_type`, `asset_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='发布记录';

-- =========================================================
-- Evaluation management
-- =========================================================

CREATE TABLE IF NOT EXISTS `sophic_agent_eval_dataset` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `dataset_id` VARCHAR(64) NOT NULL,
  `dataset_name` VARCHAR(255) NOT NULL,
  `dataset_type` VARCHAR(32) NOT NULL DEFAULT 'QA' COMMENT 'QA/CONVERSATION',
  `description` VARCHAR(1024) DEFAULT NULL,
  `owner_account_id` VARCHAR(64) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_dataset_id` (`dataset_id`),
  KEY `idx_eval_dataset_query` (`workspace_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评测集';

CREATE TABLE IF NOT EXISTS `sophic_agent_eval_dataset_item` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `dataset_id` VARCHAR(64) NOT NULL,
  `item_id` VARCHAR(64) NOT NULL,
  `question` TEXT NOT NULL,
  `reference_answer` LONGTEXT DEFAULT NULL,
  `conversation_context` JSON DEFAULT NULL,
  `tags` VARCHAR(512) DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_dataset_item_id` (`item_id`),
  KEY `idx_dataset_item_query` (`workspace_id`, `dataset_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评测集样本';

CREATE TABLE IF NOT EXISTS `sophic_agent_eval_task` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `eval_task_id` VARCHAR(64) NOT NULL,
  `task_name` VARCHAR(255) NOT NULL,
  `eval_type` VARCHAR(32) NOT NULL COMMENT 'AUTO/MANUAL',
  `target_type` VARCHAR(32) NOT NULL COMMENT 'AGENT/WORKFLOW/TOOL',
  `target_id` VARCHAR(64) NOT NULL,
  `target_version` VARCHAR(32) DEFAULT NULL,
  `dataset_id` VARCHAR(64) DEFAULT NULL,
  `eval_config` JSON DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '1-CREATED,2-RUNNING,3-FINISHED,4-FAILED',
  `operator_id` VARCHAR(64) DEFAULT NULL,
  `gmt_start` DATETIME DEFAULT NULL,
  `gmt_end` DATETIME DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_eval_task_id` (`eval_task_id`),
  KEY `idx_eval_task_query` (`workspace_id`, `target_type`, `target_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评测任务';

CREATE TABLE IF NOT EXISTS `sophic_agent_eval_result` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `result_id` VARCHAR(64) NOT NULL,
  `eval_task_id` VARCHAR(64) NOT NULL,
  `dataset_item_id` VARCHAR(64) DEFAULT NULL,
  `session_no` INT DEFAULT NULL,
  `question` TEXT DEFAULT NULL,
  `reference_answer` LONGTEXT DEFAULT NULL,
  `generated_answer` LONGTEXT DEFAULT NULL,
  `auto_score` DECIMAL(8,4) DEFAULT NULL,
  `manual_score` DECIMAL(8,4) DEFAULT NULL,
  `score_detail` JSON DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_eval_result_id` (`result_id`),
  KEY `idx_eval_result_query` (`workspace_id`, `eval_task_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评测结果';

CREATE TABLE IF NOT EXISTS `sophic_agent_perf_test_task` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `perf_task_id` VARCHAR(64) NOT NULL,
  `task_name` VARCHAR(255) NOT NULL,
  `target_type` VARCHAR(32) NOT NULL COMMENT 'AGENT/WORKFLOW/TOOL',
  `target_id` VARCHAR(64) NOT NULL,
  `target_version` VARCHAR(32) DEFAULT NULL,
  `concurrency_level` INT NOT NULL,
  `request_count` INT NOT NULL,
  `perf_config` JSON DEFAULT NULL,
  `result_summary` JSON DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '1-CREATED,2-RUNNING,3-FINISHED,4-FAILED',
  `operator_id` VARCHAR(64) DEFAULT NULL,
  `gmt_start` DATETIME DEFAULT NULL,
  `gmt_end` DATETIME DEFAULT NULL,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_perf_task_id` (`perf_task_id`),
  KEY `idx_perf_task_query` (`workspace_id`, `target_type`, `target_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='性能评测任务';
