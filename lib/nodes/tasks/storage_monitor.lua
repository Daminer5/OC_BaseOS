-- Storage Monitor Task
-- Monitors all energy storage devices and broadcasts status periodically

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
local MEK_Energy = require("hardware.mek_energy")
local Enderio_Energy = require("hardware.enderio_energy")
local ThermalEx_Energy = require("hardware.thermal_energy")

-- =============================
-- Task Execution
-- =============================

local function findStorages()
  local storages = {}
  
  -- Scan for Mekanism - Energy Tanks
  for address, ctype in component.list("MEKismEnergyTank") do
    local dev = MEK_Energy.new(address)
    if dev then
      table.insert(storages, {device = dev, type = "mek_energy", address = address})
    end
  end
  
  -- Scan for EnderIO - Energy Banks
  for address, ctype in component.list("EnderIOEnergyBank") do
    local dev = Enderio_Energy.new(address)
    if dev then
      table.insert(storages, {device = dev, type = "enderio_energy", address = address})
    end
  end
  
  -- Scan for Thermal Expansion - Energy Cells
  for address, ctype in component.list("ThermalExpansionEnergyCell") do
    local dev = ThermalEx_Energy.new(address)
    if dev then
      table.insert(storages, {device = dev, type = "thermal_energy", address = address})
    end
  end
  
  return storages
end

local function broadcastStatus(storages)
  if #storages == 0 then return end
  
  local status_list = {}
  for _, storage_info in ipairs(storages) do
    local status = storage_info.device:getStatus()
    table.insert(status_list, {
      address = storage_info.address,
      type = storage_info.type,
      status = status
    })
  end
  
  modem.broadcast(cfg.orchestrator_channel, serialization.serialize({
    type = "storage_status",
    timestamp = os.time(),
    storages = status_list
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
  local storages = findStorages()
  
  while true do
    local now = computer.uptime()
    
    -- Periodically refresh storage list (every 30 seconds)
    if (now % 30) < 1 then
      storages = findStorages()
    end
    
    -- Broadcast status
    if now - last_broadcast >= cfg.monitor_interval then
      broadcastStatus(storages)
      last_broadcast = now
    end
    
    os.sleep(1)
  end
end

return {run = run}
