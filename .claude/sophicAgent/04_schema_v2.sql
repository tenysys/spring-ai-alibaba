-- SophicAgent V2 incremental schema
-- Run after 03_schema_v1.sql

SET NAMES utf8mb4;

-- =========================================================
-- Memory expansion
-- =========================================================

CREATE TABLE IF NOT EXISTS `sa_memory_long_term` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `workspace_id` VARCHAR(64) NOT NULL,
  `user_id` VARCHAR(64) NOT NULL,
  `memory_id` VARCHAR(64) NOT NULL,
  `content` LONGTEXT NOT NULL,
  `tags` VARCHAR(512) DEFAULT NULL,
  `embedding_ref` VARCHAR(128) DEFAULT NULL,
  `score` DECIMAL(6,4) DEFAULT NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `gmt_create` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_memory_id` (`memory_id`),
  KEY `idx_memory_query` (`workspace_id`, `user_id`, `status`, `gmt_create`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='长期记忆';

-- =========================================================
-- Statistics
-- =========================================================

CREATE TABLE IF NOT EXISTS `sa_invoke_stat_daily` (
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

CREATE TABLE IF NOT EXISTS `sa_traffic_limit_rule` (
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

CREATE TABLE IF NOT EXISTS `sa_concurrent_quota` (
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

CREATE TABLE IF NOT EXISTS `sa_ha_node` (
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

CREATE TABLE IF NOT EXISTS `sa_ha_switch_record` (
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

CREATE TABLE IF NOT EXISTS `sa_runtime_config_history` (
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

CREATE TABLE IF NOT EXISTS `sa_integration_endpoint` (
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

CREATE TABLE IF NOT EXISTS `sa_integration_record` (
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

CREATE TABLE IF NOT EXISTS `sa_deploy_plan` (
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
