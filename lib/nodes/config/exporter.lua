-- Exporter Configuration
-- Defines exporter node settings

local exporter_config = {
  -- Node identification
  node_id = "exporter",
  node_type = "exporter",

  -- InfluxDB Export settings
  influx = {
    url = "http://localhost:8086/write",
    db = "oc_baseos",
    user = "",
    pass = "",
    flush_interval = 5,
  },

  -- Legacy export settings (items/fluids)
  hardware = {
    inventory_side = "left",    -- Inventory to export from
    output_side = "right",      -- Output destination
    interface_type = "hopper",  -- hopper, pipe, etc.
  },

  export = {
    enabled = true,
    auto_export = true,
    batch_size = 64,
    transfer_rate = 1,
  },

  filter = {
    enabled = false,
    whitelist = true,
    items = {},
  },

  schedule = {
    enabled = false,
    intervals = {},
  },

  monitoring = {
    enabled = true,
    update_interval = 5,
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
