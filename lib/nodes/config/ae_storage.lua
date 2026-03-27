-- AE2 Storage Configuration
-- Defines Applied Energistics 2 storage node settings

local ae_storage_config = {
  -- Node identification
  node_id = "ae_storage",
  node_type = "ae_storage",
  
  -- Hardware configuration
  hardware = {
    monitor_address = nil,     -- Will auto-detect
    interface_side = "left",   -- ME Interface side
    cable_color = 0,           -- ME cable color
  },
  
  -- Monitoring settings
  monitoring = {
    enabled = true,
    update_interval = 2,       -- seconds
    track_items = true,
    track_fluids = true,
  },
  
  -- Display settings
  display = {
    show_item_count = true,
    show_fluid_amount = true,
    max_display_rows = 20,
  },
  
  -- Thresholds (item/fluid levels)
  thresholds = {
    item_low = 5,         -- percentage below which item alerts trigger
    item_critical = 2,
    fluid_low = 10,
    fluid_critical = 5,
    storage_warning = 90,
  },
  -- Logging
  logging = {
    enabled = false,
    log_interval = 60,
  },
}

function ae_storage_config.load()
  -- TODO: Load from config file if exists
  return true
end

function ae_storage_config.save()
  -- TODO: Save to config file
end

return ae_storage_config
