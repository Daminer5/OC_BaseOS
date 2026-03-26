-- Applied Energistics 2 - Storage Monitor
local component = require("component")
local HAL = require("hardware.hal")

local AE2_Monitor = {}
AE2_Monitor.__index = AE2_Monitor

function AE2_Monitor.new(address)
  local dev = component.proxy(address)
  if not dev then
    return nil, "Invalid device address"
  end
  
  return setmetatable({
    address = address,
    device = dev
  }, AE2_Monitor)
end

function AE2_Monitor:getStatus()
  if not self.device then
    return HAL.normalizeStatus({state = false}, "ae2_monitor")
  end
  
  local ok, result = pcall(function()
    local stored = self.device.getStoredPower() or 0
    local capacity = self.device.getMaxStoredPower() or 1
    
    return {
      state = true,
      temperature = 0,
      energy_stored = stored,
      energy_capacity = capacity,
      efficiency = stored / capacity,
      throughput = 0,
      custom = {
        online_cpus = self.device.getOnlineCPUCount() or 0,
        total_cpus = self.device.getCpuCount() or 0,
        item_types = self.device.getItemCount() or 0,
        fluid_types = self.device.getFluidCount() or 0,
        item_storage_used = self.device.getStoredItemCount() or 0,
        item_storage_capacity = self.device.getItemStorageCapacity() or 0,
        fluid_storage_used = self.device.getStoredFluidAmount() or 0,
        fluid_storage_capacity = self.device.getFluidStorageCapacity() or 0
      }
    }
  end)
  
  if not ok then
    return HAL.normalizeStatus({state = false}, "ae2_monitor")
  end
  
  return HAL.normalizeStatus(result, "ae2_monitor")
end

function AE2_Monitor:getItems()
  if not self.device then return {} end
  local ok, items = pcall(function() return self.device.getItems() or {} end)
  return ok and items or {}
end

function AE2_Monitor:getFluids()
  if not self.device then return {} end
  local ok, fluids = pcall(function() return self.device.getFluids() or {} end)
  return ok and fluids or {}
end

return AE2_Monitor
