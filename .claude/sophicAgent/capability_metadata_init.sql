CREATE TABLE IF NOT EXISTS sophic_agent_datasource (
    id VARCHAR(64) PRIMARY KEY,
    datasource_name VARCHAR(128) NOT NULL,
    schema_type VARCHAR(32) NOT NULL,
    datasource_type VARCHAR(64),
    host VARCHAR(256),
    port INT,
    database_name VARCHAR(128),
    username VARCHAR(128),
    password VARCHAR(512),
    connection_url VARCHAR(512),
    datasource_status INT DEFAULT 1,
    description VARCHAR(512),
    creator_id VARCHAR(64),
    create_time DATETIME,
    update_time DATETIME
);

CREATE INDEX idx_datasource_name ON sophic_agent_datasource (datasource_name);
CREATE INDEX idx_schema_type_datasource_type ON sophic_agent_datasource (schema_type, datasource_type);

CREATE TABLE IF NOT EXISTS sophic_agent_resource (
    id VARCHAR(64) PRIMARY KEY,
    resource_id VARCHAR(64) NOT NULL,
    resource_name VARCHAR(128) NOT NULL,
    resource_type VARCHAR(32) NOT NULL,
    creator_id VARCHAR(64),
    create_time DATETIME,
    update_time DATETIME,
    UNIQUE KEY uk_resource_type_resource_id (resource_type, resource_id)
);

CREATE TABLE IF NOT EXISTS data_table_info (
    id VARCHAR(64) PRIMARY KEY,
    datasource_id VARCHAR(64) NOT NULL,
    schema_name VARCHAR(128),
    table_name VARCHAR(128) NOT NULL,
    table_comment VARCHAR(512),
    refresh_version VARCHAR(64),
    is_delete TINYINT(1) DEFAULT 0,
    create_time DATETIME,
    update_time DATETIME,
    UNIQUE KEY uk_datasource_schema_table (datasource_id, schema_name, table_name),
    KEY idx_data_table_info_datasource (datasource_id)
);

CREATE TABLE IF NOT EXISTS data_field_info (
    id VARCHAR(64) PRIMARY KEY,
    datasource_id VARCHAR(64) NOT NULL,
    table_id VARCHAR(64) NOT NULL,
    table_name VARCHAR(128),
    column_name VARCHAR(128) NOT NULL,
    column_comment VARCHAR(512),
    data_type VARCHAR(128),
    is_primary TINYINT(1),
    is_foreign TINYINT(1),
    is_not_null TINYINT(1),
    field_status VARCHAR(16),
    refresh_version VARCHAR(64),
    is_delete TINYINT(1) DEFAULT 0,
    create_time DATETIME,
    update_time DATETIME,
    UNIQUE KEY uk_table_column (table_id, column_name),
    KEY idx_field_datasource_table (datasource_id, table_id),
    KEY idx_field_status (field_status)
);

CREATE TABLE IF NOT EXISTS data_relation_info (
    id VARCHAR(64) PRIMARY KEY,
    datasource_id VARCHAR(64) NOT NULL,
    source_table_id VARCHAR(64),
    source_name VARCHAR(128) NOT NULL,
    source_field_name VARCHAR(128) NOT NULL,
    target_table_id VARCHAR(64),
    target_name VARCHAR(128) NOT NULL,
    target_field_name VARCHAR(128) NOT NULL,
    relation_type VARCHAR(16),
    description VARCHAR(512),
    create_time DATETIME,
    update_time DATETIME,
    UNIQUE KEY uk_datasource_relation (datasource_id, source_name, source_field_name, target_name, target_field_name),
    KEY idx_relation_source (datasource_id, source_table_id),
    KEY idx_relation_target (datasource_id, target_table_id)
);

CREATE TABLE IF NOT EXISTS data_semantic_model (
    id VARCHAR(64) PRIMARY KEY,
    datasource_id VARCHAR(64) NOT NULL,
    table_id VARCHAR(64) NOT NULL,
    field_id VARCHAR(64),
    semantic_level VARCHAR(16) NOT NULL,
    model_name VARCHAR(128),
    field_name VARCHAR(128),
    business_name VARCHAR(128),
    synonyms VARCHAR(512),
    business_description VARCHAR(1024),
    status INT DEFAULT 1,
    meta_data TEXT,
    create_time DATETIME,
    update_time DATETIME,
    UNIQUE KEY uk_semantic_target (datasource_id, table_id, field_id, semantic_level),
    KEY idx_semantic_datasource_level (datasource_id, semantic_level)
);

CREATE TABLE IF NOT EXISTS agent_resource_binding (
    id VARCHAR(64) PRIMARY KEY,
    agent_id VARCHAR(64) NOT NULL,
    resource_type VARCHAR(32) NOT NULL,
    resource_id VARCHAR(64) NOT NULL,
    meta_data TEXT,
    creator_id VARCHAR(64),
    create_time DATETIME,
    update_time DATETIME,
    UNIQUE KEY uk_agent_resource_binding (agent_id, resource_type, resource_id)
);

CREATE TABLE IF NOT EXISTS agent_resource_binding_item (
    id VARCHAR(64) PRIMARY KEY,
    binding_id VARCHAR(64) NOT NULL,
    item_type VARCHAR(16) NOT NULL,
    item_id VARCHAR(64) NOT NULL,
    item_name VARCHAR(256),
    item_meta_data TEXT,
    sort_no INT,
    create_time DATETIME,
    update_time DATETIME,
    UNIQUE KEY uk_agent_resource_binding_item (binding_id, item_type, item_id)
);
