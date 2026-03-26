-- Mekanism - Energy Tank Monitoring
local component = require("component")
local HAL = require("hardware.hal")

local MEK_Energy = {}
MEK_Energy.__index = MEK_Energy

function MEK_Energy.new(address)
  local dev = component.proxy(address)
  if not dev then
    return nil, "Invalid device address"
  end
  
  return setmetatable({
    address = address,
    device = dev
  }, MEK_Energy)
end

function MEK_Energy:getStatus()
  if not self.device then
    return HAL.normalizeStatus({state = false}, "mek_energy")
  end
  
  local ok, result = pcall(function()
    local stored = self.device.getEnergy() or 0
    local capacity = self.device.getMaxEnergy() or 1
    
    return {
      state = true,
      temperature = 0,
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
    return HAL.normalizeStatus({state = false}, "mek_energy")
  end
  
  return HAL.normalizeStatus(result, "mek_energy")
end

return MEK_Energy
