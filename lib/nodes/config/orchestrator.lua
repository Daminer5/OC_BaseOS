-- Orchestrator Configuration
-- Defines orchestrator/supervisor node settings

local orchestrator_config = {
  -- Node identification
  node_id = "orchestrator",
  node_type = "supervisor",
  
  -- Communication settings
  modem = {
    port = 1000,
    timeout = 10,
    retry_attempts = 3,
  },
  
  -- Monitoring intervals
  intervals = {
    health_check = 5,
    status_update = 10,
    log_rotation = 3600,
  },
  
  -- Storage settings
  storage = {
    max_records = 10000,
    retention_days = 30,
    auto_cleanup = true,
  },
  
  -- Alert settings
  alerts = {
    enabled = true,
    critical_level = 1,
    warning_level = 2,
    info_level = 3,
  },
}

function orchestrator_config.load()
  -- TODO: Load from config file if exists
  return true
end

function orchestrator_config.save()
  -- TODO: Save to config file
end

return orchestrator_config
