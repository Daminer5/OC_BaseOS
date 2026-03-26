-- Thermal Expansion - Energy Cell Monitoring
local component = require("component")
local HAL = require("hardware.hal")

local ThermalEx_Energy = {}
ThermalEx_Energy.__index = ThermalEx_Energy

function ThermalEx_Energy.new(address)
  local dev = component.proxy(address)
  if not dev then
    return nil, "Invalid device address"
  end
  
  return setmetatable({
    address = address,
    device = dev
  }, ThermalEx_Energy)
end

function ThermalEx_Energy:getStatus()
  if not self.device then
    return HAL.normalizeStatus({state = false}, "thermal_energy")
  end
  
  local ok, result = pcall(function()
    local stored = self.device.getEnergyStored() or 0
    local capacity = self.device.getMaxEnergyStored() or 1
    
    return {
      state = true,
      temperature = self.device.getTemperature() or 0,
      energy_stored = stored,
      energy_capacity = capacity,
      efficiency = stored / capacity,
      throughput = 0,
      custom = {
        charge_rate = self.device.getInputRate() or 0,
        discharge_rate = self.device.getOutputRate() or 0,
        fill_percentage = (stored / capacity) * 100
      }
    }
  end)
  
  if not ok then
    return HAL.normalizeStatus({state = false}, "thermal_energy")
  end
  
  return HAL.normalizeStatus(result, "thermal_energy")
end

return ThermalEx_Energy
