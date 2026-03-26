-- Hardware Abstraction Layer - Base Interface
-- Provides common interface for all device types

local HAL = {}

-- =============================
-- Standardized Status Format
-- =============================
-- All devices should return status with these keys (where applicable):
-- {
--   type = "reactor" | "turbine" | "storage" | "tank" | "ae2_storage" | etc
--   state = true/false (online/offline)
--   temperature = number (Kelvin, for thermal devices)
--   energy_stored = number (RF or equivalent)
--   energy_capacity = number (RF or equivalent)
--   efficiency = number (0.0 to 1.0)
--   throughput = number (RF/t or items/s)
--   custom = {} (device-specific fields)
-- }

function HAL.normalizeStatus(rawStatus, deviceType)
  -- Convert raw component data to standardized format
  return {
    type = deviceType,
    state = rawStatus.state ~= nil and rawStatus.state or true,
    temperature = rawStatus.temperature or 0,
    energy_stored = rawStatus.energy_stored or 0,
    energy_capacity = rawStatus.energy_capacity or 0,
    efficiency = rawStatus.efficiency or 0,
    throughput = rawStatus.throughput or 0,
    custom = rawStatus.custom or {}
  }
end

return HAL
