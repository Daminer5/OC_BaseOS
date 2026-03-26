-- Reactor Monitor Task
-- Monitors all reactor devices and broadcasts status periodically

local component = require("component")
local serialization = require("serialization")
local computer = require("computer")

local modem = component.modem

-- Task configuration
local cfg = {
  orchestrator_channel = 1234,
  monitor_interval = 5,  -- seconds
  critical_temp = 1200,  -- Kelvin
  warning_temp = 1000    -- Kelvin
}

-- Import hardware layer
local BR_Reactor = require("hardware.br_reactor")
local BR_Turbine = require("hardware.br_turbine")
local MEK_Fission = require("hardware.mek_fission")
local MEK_Fusion = require("hardware.mek_fusion")

-- =============================
-- Task Execution
-- =============================

local function findReactors()
  local reactors = {}
  
  -- Scan for Big Reactors - Reactors
  for address, ctype in component.list("BigReactors_Reactor") do
    local dev = BR_Reactor.new(address)
    if dev then
      table.insert(reactors, {device = dev, type = "br_reactor", address = address})
    end
  end
  
  -- Scan for Big Reactors - Turbines
  for address, ctype in component.list("BigReactors_Turbine") do
    local dev = BR_Turbine.new(address)
    if dev then
      table.insert(reactors, {device = dev, type = "br_turbine", address = address})
    end
  end
  
  -- Scan for Mekanism - Fission Reactors
  for address, ctype in component.list("MEKismFissionReactor") do
    local dev = MEK_Fission.new(address)
    if dev then
      table.insert(reactors, {device = dev, type = "mek_fission", address = address})
    end
  end
  
  -- Scan for Mekanism - Fusion Reactors
  for address, ctype in component.list("MEKismFusionReactor") do
    local dev = MEK_Fusion.new(address)
    if dev then
      table.insert(reactors, {device = dev, type = "mek_fusion", address = address})
    end
  end
  
  return reactors
end

local function broadcastStatus(reactors)
  if #reactors == 0 then return end
  
  local status_list = {}
  for _, reactor_info in ipairs(reactors) do
    local status = reactor_info.device:getStatus()
    table.insert(status_list, {
      address = reactor_info.address,
      type = reactor_info.type,
      status = status
    })
  end
  
  modem.broadcast(cfg.orchestrator_channel, serialization.serialize({
    type = "reactor_status",
    timestamp = os.time(),
    reactors = status_list
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
  local reactors = findReactors()
  
  while true do
    local now = computer.uptime()
    
    -- Periodically refresh reactor list (every 30 seconds)
    if (now % 30) < 1 then
      reactors = findReactors()
    end
    
    -- Broadcast status
    if now - last_broadcast >= cfg.monitor_interval then
      broadcastStatus(reactors)
      last_broadcast = now
    end
    
    os.sleep(1)
  end
end

return {run = run}
