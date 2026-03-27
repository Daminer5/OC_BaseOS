-- HMI Configuration
-- Defines HMI-specific settings and parameters

local hmi_config = {
  -- Display settings
  display = {
    monitor_address = nil,  -- Will be auto-detected
    width = 160,
    height = 50,
    refresh_rate = 1,       -- Hz
  },
  
  -- Update intervals (in seconds)
  intervals = {
    dashboard_update = 1,
    status_update = 2,
    alert_check = 0.5,
  },
  
  -- Color scheme
  colors = {
    background = 0x000000,
    text = 0xFFFFFF,
    accent = 0x00FF00,
    warning = 0xFFFF00,
    error = 0xFF0000,
  },
  
  -- Feature flags
  features = {
    show_charts = true,
    enable_alerts = true,
    enable_logging = false,
  },
}

-- Load configuration from file
function hmi_config.load()
  -- TODO: Load from config file if exists
  return true
end

-- Save configuration to file
function hmi_config.save()
  -- TODO: Save to config file
end

return hmi_config
