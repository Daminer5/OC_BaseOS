-- AE2 Monitor Task
-- Monitors Applied Energistics 2 ME networks and broadcasts status periodically

local component = require("component")
local serialization = require("serialization")
local computer = require("computer")

local modem = component.modem

-- Task configuration
local cfg = {
  orchestrator_channel = 1234,
  monitor_interval = 5,  -- seconds
  critical_level = 0.05, -- 5% capacity
  warning_level = 0.2    -- 20% capacity
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
    local items = net_info.device:getItems()
    local fluids = net_info.device:getFluids()
    
    -- Limit item/fluid lists to prevent overly large broadcasts
    local item_count = 0
    local fluid_count = 0
    for _ in pairs(items) do item_count = item_count + 1 end
    for _ in pairs(fluids) do fluid_count = fluid_count + 1 end
    
    table.insert(status_list, {
      address = net_info.address,
      type = net_info.type,
      status = status,
      item_count = item_count,
      fluid_count = fluid_count
    })
  end
  
  modem.broadcast(cfg.orchestrator_channel, serialization.serialize({
    type = "ae2_status",
    timestamp = os.time(),
    networks = status_list
  }))
end

local function run(task_cfg)
  -- Merge config
  if task_cfg then
    for k, v in pairs(task_cfg) do
      cfg[k] = v
    end
  end
  
  modem.open(cfg.orchestrator_channel)
  
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
