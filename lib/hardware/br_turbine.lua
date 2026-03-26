-- Big Reactors - Turbine Monitoring
local component = require("component")
local HAL = require("hardware.hal")

local BR_Turbine = {}
BR_Turbine.__index = BR_Turbine

function BR_Turbine.new(address)
  local dev = component.proxy(address)
  if not dev then
    return nil, "Invalid device address"
  end
  
  return setmetatable({
    address = address,
    device = dev
  }, BR_Turbine)
end

function BR_Turbine:getStatus()
  if not self.device then
    return HAL.normalizeStatus({state = false}, "br_turbine")
  end
  
  local ok, result = pcall(function()
    return {
      state = self.device.getActive(),
      temperature = self.device.getTemperature(),
      energy_stored = self.device.getEnergyStored(),
      energy_capacity = self.device.getMaxEnergyStored(),
      rotor_speed = self.device.getRotorSpeed(),
      rotor_max_speed = 2000,
      efficiency = (self.device.getRotorSpeed() or 0) / 2000,
      throughput = self.device.getEnergyProducedLastTick() or 0,
      custom = {
        rotor_speed = self.device.getRotorSpeed() or 0,
        fluid_amount = self.device.getFluidAmount() or 0,
        fluid_capacity = self.device.getFluidCapacity() or 0,
        energy_produced_last_tick = self.device.getEnergyProducedLastTick() or 0,
        shaft_damage = self.device.getShaftDamage() or 0
      }
    }
  end)
  
  if not ok then
    return HAL.normalizeStatus({state = false}, "br_turbine")
  end
  
  return HAL.normalizeStatus(result, "br_turbine")
end

function BR_Turbine:setActive(state)
  if not self.device then return false end
  local ok = pcall(function() self.device.setActive(state) end)
  return ok
end

return BR_Turbine
