-- Generic Node Configuration
-- Defines generic/fallback node settings for any unspecialized node

local generic_config = {
  -- Node identification
  node_id = "generic",
  node_type = "generic",
  
  -- Basic settings
  basic = {
    enabled = true,
    name = "Generic Node",
    description = "A generic node for miscellaneous tasks",
  },
  
  -- Hardware auto-detection
  auto_detect = {
    enabled = true,
    scan_interval = 5,         -- seconds
    max_peripherals = 10,
  },
  
  -- Communication
  communication = {
    modem_port = 2000,
    timeout = 10,
    retry_attempts = 3,
  },
  
  -- Logging
  logging = {
    enabled = true,
    level = "INFO",            -- DEBUG, INFO, WARNING, ERROR
    file = "/var/logs/generic.log",
  },
  
  -- Task execution
  tasks = {
    max_concurrent = 5,
    task_timeout = 300,        -- seconds
    auto_cleanup = true,
  },
  
  -- Storage
  storage = {
    cache_enabled = true,
    cache_ttl = 60,            -- seconds
    max_cache_size = 1000,
  },
}

function generic_config.load()
  -- TODO: Load from config file if exists
  return true
end

function generic_config.save()
  -- TODO: Save to config file
end

return generic_config
