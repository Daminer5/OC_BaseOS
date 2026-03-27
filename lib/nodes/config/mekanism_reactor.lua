-- Mekanism Reactor Configuration
-- Defines Mekanism reactor node settings (Fission and Fusion)

local mekanism_config = {
  -- Node identification
  node_id = "mekanism_reactor",
  node_type = "mekanism_reactor",
  
  -- Reactor types
  reactor_types = {
    fission = true,
    fusion = true,
  },
  
  -- Fission reactor settings
  fission = {
    enabled = true,
    control_side = "left",
    target_burn_rate = 50,     -- % 
    max_heat = 100,            -- %
    temperature_target = 500,  -- K
  },
  
  -- Fusion reactor settings
  fusion = {
    enabled = true,
    control_side = "right",
    plasma_heat_target = 50,   -- %
    case_heat_max = 100,       -- %
    target_power = 50,         -- MW
  },
  
  -- Monitoring
  monitoring = {
    enabled = true,
    update_interval = 2,       -- seconds
    log_interval = 15,         -- seconds
  },
  
  -- Safety
  safety = {
    enable_scrams = true,
    scram_heat_threshold = 95, -- %
    scram_cooldown = 30,       -- seconds
  },
}

function mekanism_config.load()
  -- TODO: Load from config file if exists
  return true
end

function mekanism_config.save()
  -- TODO: Save to config file
end

return mekanism_config
