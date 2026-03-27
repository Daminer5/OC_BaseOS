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
    local online_cpus = self.device.getOnlineCPUCount() or 0
    local total_cpus = self.device.getCPUCount() or 1
    local cpu_usage = (total_cpus - online_cpus) / total_cpus * 100
    local item_types = self.device.getItemCount() or 0
    local fluid_types = self.device.getFluidCount() or 0
    local item_used = self.device.getStoredItemCount() or 0
    local item_capacity = self.device.getItemStorageCapacity() or 1
    local fluid_used = self.device.getStoredFluidAmount() or 0
    local fluid_capacity = self.device.getFluidStorageCapacity() or 1

    return {
      state = true,
      status = "online",
      custom = {
        item_types = item_types,
        fluid_types = fluid_types,
        item_storage_used = item_used,
        item_storage_capacity = item_capacity,
        fluid_storage_used = fluid_used,
        fluid_storage_capacity = fluid_capacity
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
