-- Mekanism - Fusion Reactor Monitoring
local component = require("component")
local HAL = require("hardware.hal")

local MEK_Fusion = {}
MEK_Fusion.__index = MEK_Fusion

function MEK_Fusion.new(address)
  local dev = component.proxy(address)
  if not dev then
    return nil, "Invalid device address"
  end
  
  return setmetatable({
    address = address,
    device = dev
  }, MEK_Fusion)
end

function MEK_Fusion:getStatus()
  if not self.device then
    return HAL.normalizeStatus({state = false}, "mek_fusion")
  end
  
  local ok, result = pcall(function()
    return {
      state = self.device.isPlasmaIgnited(),
      temperature = self.device.getPlasmaTemperature(),
      energy_stored = self.device.getEnergy(),
      energy_capacity = self.device.getMaxEnergy(),
      efficiency = (self.device.getProductionRate() or 0) / (self.device.getPlasmaTemperature() or 1),
      throughput = self.device.getEnergyProducedLastTick() or 0,
      custom = {
        plasma_temperature = self.device.getPlasmaTemperature() or 0,
        case_temperature = self.device.getCaseTemperature() or 0,
        production_rate = self.device.getProductionRate() or 0,
        fuel_temperature = self.device.getFuelTemperature() or 0,
        fuel_rate = self.device.getFuelInputRate() or 0
      }
    }
  end)
  
  if not ok then
    return HAL.normalizeStatus({state = false}, "mek_fusion")
  end
  
  return HAL.normalizeStatus(result, "mek_fusion")
end

function MEK_Fusion:setActive(state)
  if not self.device then return false end
  local ok = pcall(function() self.device.setPlasmaTemperature(state and 100000000 or 0) end)
  return ok
end

return MEK_Fusion
