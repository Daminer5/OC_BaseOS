-- AE2 Monitor Task (Item/Fluid levels only)
-- Monitors AE2 storage network and sends lightweight status to orchestrator

local component = require("component")
local serialization = require("serialization")
local computer = require("computer")
local cfg = require("nodes.config.ae_storage")

local modem = component.modem

-- runtime defaults
local task_cfg = {
  orchestrator_channel = 1234,
  monitor_interval = cfg.monitoring.update_interval or 5,
}

-- Import hardware layer
local AE2_Monitor = require("hardware.ae2_monitor")

-- =============================
-- Task Execution
-- =============================

local function findAE2Networks()
  local networks = {}
  
  -- Scan for ME Controller or ME Storage Monitor
  for address, ctype in component.list("me_") do
    if ctype:find("controller") or ctype:find("monitor") or ctype == "me_interface" then
      local dev = AE2_Monitor.new(address)
      if dev then
        table.insert(networks, {device = dev, type = "ae2_network", address = address})
      end
    end
  end
  
  return networks
end

local function broadcastStatus(networks)
  if #networks == 0 then return end

  local status_list = {}
  for _, net_info in ipairs(networks) do
    local status = net_info.device:getStatus()

    local item_used = status.custom and status.custom.item_storage_used or 0
    local item_capacity = status.custom and status.custom.item_storage_capacity or 1
    local fluid_used = status.custom and status.custom.fluid_storage_used or 0
    local fluid_capacity = status.custom and status.custom.fluid_storage_capacity or 1

    local item_pct = math.min(100, math.floor((item_used / item_capacity) * 100 + 0.5))
    local fluid_pct = math.min(100, math.floor((fluid_used / fluid_capacity) * 100 + 0.5))

    -- alert calculations
    if cfg.monitoring.track_items and item_pct >= cfg.thresholds.storage_warning then
      pcall(function()
        local alerts = require("alerts")
        alerts.createAlert("ae_storage", "item_capacity", alerts.SEVERITY.WARNING,
          "AE2 item storage nearing capacity: "..item_pct.."%", {item_pct=item_pct})
      end)
    end

    if cfg.monitoring.track_fluids and fluid_pct >= cfg.thresholds.storage_warning then
      pcall(function()
        local alerts = require("alerts")
        alerts.createAlert("ae_storage", "fluid_capacity", alerts.SEVERITY.WARNING,
          "AE2 fluid storage nearing capacity: "..fluid_pct.."%", {fluid_pct=fluid_pct})
      end)
    end

    -- low item/fluid thresholds
    if cfg.monitoring.track_items and cfg.thresholds.item_low and item_pct <= cfg.thresholds.item_low then
      pcall(function()
        local alerts = require("alerts")
        alerts.createAlert("ae_storage", "item_low", alerts.SEVERITY.CRITICAL,
          "AE2 item stock low: "..item_pct.."%", {item_pct=item_pct})
      end)
    end

    if cfg.monitoring.track_fluids and cfg.thresholds.fluid_low and fluid_pct <= cfg.thresholds.fluid_low then
      pcall(function()
        local alerts = require("alerts")
        alerts.createAlert("ae_storage", "fluid_low", alerts.SEVERITY.CRITICAL,
          "AE2 fluid stock low: "..fluid_pct.."%", {fluid_pct=fluid_pct})
      end)
    end

    table.insert(status_list, {
      address = net_info.address,
      type = net_info.type,
      status = status,
      item_count = status.custom and status.custom.item_types or 0,
      fluid_count = status.custom and status.custom.fluid_types or 0,
      item_used = item_used,
      item_capacity = item_capacity,
      fluid_used = fluid_used,
      fluid_capacity = fluid_capacity,
      item_pct = item_pct,
      fluid_pct = fluid_pct
    })
  end

  modem.broadcast(task_cfg.orchestrator_channel, serialization.serialize({
    type = "ae2_status",
    timestamp = os.time(),
    networks = status_list
  }))
end

local function run(task_config)
  -- Merge config
  if task_config then
    for k, v in pairs(task_config) do
      task_cfg[k] = v
    end
  end

  modem.open(task_cfg.orchestrator_channel)

  local last_broadcast = 0
  local networks = findAE2Networks()
  
  while true do
    local now = computer.uptime()
    
    -- Periodically refresh network list (every 30 seconds)
    if (now % 30) < 1 then
      networks = findAE2Networks()
    end
    
    -- Broadcast status
    if now - last_broadcast >= cfg.monitor_interval then
      broadcastStatus(networks)
      last_broadcast = now
    end
    
    os.sleep(1)
  end
end

return {run = run}
