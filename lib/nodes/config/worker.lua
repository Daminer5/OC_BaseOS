-- Worker Configuration
-- Defines worker node settings

local worker_config = {
  -- Node identification
  node_id = "worker",
  node_type = "worker",
  
  -- Worker capabilities
  capabilities = {
    can_process = true,
    can_farm = true,
    can_mine = true,
    can_craft = true,
  },
  
  -- Processing settings
  processing = {
    enabled = true,
    max_jobs = 10,
    job_timeout = 300,         -- seconds
    auto_retry = true,
    retry_attempts = 3,
  },
  
  -- Farm settings (if applicable)
  farm = {
    enabled = false,
    crop_types = {},
    harvest_interval = 3600,   -- seconds
  },
  
  -- Mining settings (if applicable)
  mining = {
    enabled = false,
    target_ores = {},
    max_excavation_depth = 64,
  },
  
  -- Crafting settings (if applicable)
  crafting = {
    enabled = false,
    max_queue_size = 100,
    auto_craft = true,
  },
  
  -- Communication
  communication = {
    register_interval = 10,    -- seconds
    heartbeat_interval = 5,    -- seconds
  },
}

function worker_config.load()
  -- TODO: Load from config file if exists
  return true
end

function worker_config.save()
  -- TODO: Save to config file
end

return worker_config
