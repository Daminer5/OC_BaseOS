-- Exporter Configuration
-- Defines exporter node settings

local exporter_config = {
  -- Node identification
  node_id = "exporter",
  node_type = "exporter",
  
  -- Hardware configuration
  hardware = {
    inventory_side = "left",    -- Inventory to export from
    output_side = "right",      -- Output destination
    interface_type = "hopper",  -- hopper, pipe, etc.
  },
  
  -- Export settings
  export = {
    enabled = true,
    auto_export = true,
    batch_size = 64,            -- items per batch
    transfer_rate = 1,          -- items per tick
  },
  
  -- Filtering
  filter = {
    enabled = false,
    whitelist = true,           -- true: whitelist, false: blacklist
    items = {},                 -- Whitelisted/blacklisted items
  },
  
  -- Scheduling
  schedule = {
    enabled = false,
    intervals = {},             -- Time-based export intervals
  },
  
  -- Monitoring
  monitoring = {
    enabled = true,
    update_interval = 5,        -- seconds
    track_exports = true,
  },
}

function exporter_config.load()
  -- TODO: Load from config file if exists
  return true
end

function exporter_config.save()
  -- TODO: Save to config file
end

return exporter_config
