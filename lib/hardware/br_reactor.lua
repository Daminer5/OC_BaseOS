-- Big Reactors - Passive Reactor Monitoring
local component = require("component")
local HAL = require("hardware.hal")

local BR_Reactor = {}
BR_Reactor.__index = BR_Reactor

function BR_Reactor.new(address)
  local dev = component.proxy(address)
  if not dev then
    return nil, "Invalid device address"
  end
  
  return setmetatable({
    address = address,
    device = dev
  }, BR_Reactor)
end

function BR_Reactor:getStatus()
  if not self.device then
    return HAL.normalizeStatus({state = false}, "br_reactor")
  end
  
  local ok, result = pcall(function()
    return {
      state = self.device.getActive(),
      temperature = self.device.getTemperature(),
      energy_stored = self.device.getEnergyStored(),
      energy_capacity = self.device.getMaxEnergyStored(),
      control_rod_level = self.device.getControlRodLevel(0),
      fuel_amount = self.device.getFuelAmount(),
      fuel_capacity = self.device.getFuelCapacity(),
      efficiency = (self.device.getEnergyProducedLastTick() or 1) / (self.device.getHeatProducedLastTick() or 1),
      throughput = self.device.getEnergyProducedLastTick() or 0,
      custom = {
        fuel_amount = self.device.getFuelAmount(),
        fuel_capacity = self.device.getFuelCapacity(),
        control_rod_level = self.device.getControlRodLevel(0),
        energy_produced_last_tick = self.device.getEnergyProducedLastTick() or 0,
        heat_produced_last_tick = self.device.getHeatProducedLastTick() or 0
      }
    }
  end)
  
  if not ok then
    return HAL.normalizeStatus({state = false}, "br_reactor")
  end
  
  return HAL.normalizeStatus(result, "br_reactor")
end

function BR_Reactor:setActive(state)
  if not self.device then return false end
  local ok = pcall(function() self.device.setActive(state) end)
  return ok
end

function BR_Reactor:setControlRodLevel(level)
  if not self.device then return false end
  local ok = pcall(function() self.device.setControlRodLevel(0, level) end)
  return ok
end

return BR_Reactor
