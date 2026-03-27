-- Database Configuration
-- Defines central database node settings

local database_config = {
  -- Database identification
  node_id = "database",
  
  -- Storage backend
  backend = "sqlite",  -- Options: sqlite, file
  
  -- File paths
  paths = {
    db_file = "/var/db/system.db",
    backup_dir = "/var/backups",
    log_dir = "/var/logs",
  },
  
  -- Database settings
  database = {
    max_connections = 10,
    connection_timeout = 30,
    query_timeout = 60,
    auto_backup = true,
    backup_interval = 3600,  -- seconds
  },
  
  -- Tables/Collections to maintain
  tables = {
    "events",
    "logs",
    "metrics",
    "alerts",
    "nodes",
  },
  
  -- Retention policies
  retention = {
    events_days = 30,
    logs_days = 7,
    metrics_days = 90,
    alerts_days = 30,
  },
}

function database_config.load()
  -- TODO: Load from config file if exists
  return true
end

function database_config.save()
  -- TODO: Save to config file
end

return database_config
