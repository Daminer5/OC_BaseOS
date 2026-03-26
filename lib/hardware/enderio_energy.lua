-- EnderIO - Energy Bank Monitoring
local component = require("component")
local HAL = require("hardware.hal")

local Enderio_Energy = {}
Enderio_Energy.__index = Enderio_Energy

function Enderio_Energy.new(address)
  local dev = component.proxy(address)
  if not dev then
    return nil, "Invalid device address"
  end
  
  return setmetatable({
    address = address,
    device = dev
  }, Enderio_Energy)
end

function Enderio_Energy:getStatus()
  if not self.device then
    return HAL.normalizeStatus({state = false}, "enderio_energy")
  end
  
  local ok, result = pcall(function()
    local stored = self.device.getEnergyStored() or 0
    local capacity = self.device.getMaxEnergyStored() or 1
    
    return {
      state = true,
      temperature = 0,
      energy_stored = stored,
      energy_capacity = capacity,
      efficiency = stored / capacity,
      throughput = 0,
      custom = {
        input_rate = self.device.getInputRate() or 0,
        output_rate = self.device.getOutputRate() or 0,
        fill_percentage = (stored / capacity) * 100
      }
    }
  end)
  
  if not ok then
    return HAL.normalizeStatus({state = false}, "enderio_energy")
  end
  
  return HAL.normalizeStatus(result, "enderio_energy")
end

return Enderio_Energy
