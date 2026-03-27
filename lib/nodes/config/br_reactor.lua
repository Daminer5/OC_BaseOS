-- BR (Big Reactor) Configuration
-- Defines Big Reactor node settings

local br_reactor_config = {
  -- Node identification
  node_id = "br_reactor",
  node_type = "br_reactor",
  
  -- Hardware configuration
  hardware = {
    reactor_side = "left",  -- Peripheral side
    turbine_sides = {},     -- Turbine peripheral sides
  },
  
  -- Operating parameters
  operation = {
    target_temp = 2000,
    max_temp = 2500,
    min_temp = 500,
    target_power = 50,      -- MW
    max_power = 100,        -- MW
  },
  
  -- Monitoring
  monitoring = {
    enabled = true,
    update_interval = 1,    -- seconds
    log_interval = 10,      -- seconds
  },
  
  -- Control settings
  control = {
    auto_control = true,
    enable_shutdown = true,
    shutdown_temp = 2400,
  },
}

function br_reactor_config.load()
  -- TODO: Load from config file if exists
  return true
end

function br_reactor_config.save()
  -- TODO: Save to config file
end

return br_reactor_config
