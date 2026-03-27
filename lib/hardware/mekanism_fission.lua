-- Mekanism - Fission Reactor Monitoring
local component = require("component")
local HAL = require("hardware.hal")

local MEK_Fission = {}
MEK_Fission.__index = MEK_Fission

function MEK_Fission.new(address)
  local dev = component.proxy(address)
  if not dev then
    return nil, "Invalid device address"
  end
  
  return setmetatable({
    address = address,
    device = dev
  }, MEK_Fission)
end

function MEK_Fission:getStatus()
  if not self.device then
    return HAL.normalizeStatus({state = false}, "mek_fission")
  end
  
  local ok, result = pcall(function()
    local heating_rate = self.device.getHeatingRate()
    local heat_capacity = self.device.getHeatCapacity()
    
    return {
      state = self.device.isReacting(),
      temperature = self.device.getTemperature(),
      energy_stored = self.device.getEnergy(),
      energy_capacity = self.device.getMaxEnergy(),
      efficiency = (heating_rate or 0) / (heat_capacity or 1),
      throughput = self.device.getEnergyProducedLastTick() or 0,
      custom = {
        heating_rate = heating_rate or 0,
        heat_capacity = heat_capacity or 0,
        fuel_amount = self.device.getFuel() or 0,
        waste_amount = self.device.getWaste() or 0,
        coolant_temp = self.device.getCoolantTemperature() or 0,
        heated_coolant_temp = self.device.getHeatedCoolantTemperature() or 0,
        burn_rate = self.device.getBurnRate() or 0
      }
    }
  end)
  
  if not ok then
    return HAL.normalizeStatus({state = false}, "mek_fission")
  end
  
  return HAL.normalizeStatus(result, "mek_fission")
end

function MEK_Fission:setActive(state)
  if not self.device then return false end
  local ok = pcall(function() self.device.setReacting(state) end)
  return ok
end

return MEK_Fission
