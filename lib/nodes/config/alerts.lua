-- Alerts Configuration
-- Defines alert system settings

local alerts_config = {
  -- Alert system
  enabled = true,
  
  -- Alert levels
  levels = {
    CRITICAL = 1,
    WARNING = 2,
    INFO = 3,
    DEBUG = 4,
  },
  
  -- Default thresholds
  thresholds = {
    cpu_usage = 80,
    memory_usage = 85,
    disk_usage = 90,
    temperature = 80,
  },
  
  -- Alert channels
  channels = {
    log = true,
    display = true,
    sound = false,
    network = true,
  },
  
  -- Notification settings
  notifications = {
    enabled = true,
    cooldown = 60,  -- seconds between repeated alerts
    max_buffer = 100,
  },
  
  -- Sound settings (if enabled)
  sound = {
    frequency = 1000,
    duration = 0.5,
  },
}

function alerts_config.load()
  -- TODO: Load from config file if exists
  return true
end

function alerts_config.save()
  -- TODO: Save to config file
end

return alerts_config
