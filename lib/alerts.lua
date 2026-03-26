-- Alert/Threshold System
-- Manages device thresholds, generates alerts, and broadcasts to HMI nodes

local component = require("component")
local serialization = require("serialization")
local computer = require("computer")

local modem = component.modem

local M = {}

-- =============================
-- Alert Severity Levels
-- =============================

M.SEVERITY = {
  INFO = 0,
  WARNING = 1,
  CRITICAL = 2
}

M.SEVERITY_NAMES = {
  [0] = "INFO",
  [1] = "WARNING",
  [2] = "CRITICAL"
}

-- =============================
-- Default Thresholds
-- =============================

M.THRESHOLDS = {
  br_reactor = {
    temp_critical = 1200,
    temp_warning = 1000,
    fuel_low = 0.1
  },
  br_turbine = {
    rotor_damage = 0.5,
    speed_warning = 1500
  },
  mek_fission = {
    temp_critical = 900,
    temp_warning = 700,
    fuel_low = 0.05
  },
  mek_fusion = {
    temp_critical = 100000000,
    temp_warning = 50000000,
    plasma_too_cold = 5000000
  },
  thermal_energy = {
    capacity_critical = 0.05,
    capacity_warning = 0.2
  },
  mek_energy = {
    capacity_critical = 0.05,
    capacity_warning = 0.2
  },
  enderio_energy = {
    capacity_critical = 0.05,
    capacity_warning = 0.2
  },
  ae2_network = {
    capacity_critical = 0.05,
    capacity_warning = 0.2,
    cpu_warning = 1
  }
}

-- =============================
-- Alert Queue
-- =============================

M.alerts = {}
M.alert_id_counter = 0

local function generateAlertId()
  M.alert_id_counter = M.alert_id_counter + 1
  return M.alert_id_counter
end

-- =============================
-- Alert Generation
-- =============================

function M.createAlert(device_id, device_type, severity, message, details)
  local alert = {
    id = generateAlertId(),
    device_id = device_id,
    device_type = device_type,
    severity = severity,
    severity_name = M.SEVERITY_NAMES[severity] or "UNKNOWN",
    message = message,
    details = details or {},
    timestamp = os.time(),
    created_at = computer.uptime()
  }
  
  table.insert(M.alerts, alert)
  return alert
end

function M.checkDeviceStatus(device_id, device_type, status)
  -- Check device status against thresholds and generate alerts
  if not status then return end
  
  local threshold_set = M.THRESHOLDS[device_type]
  if not threshold_set then return end
  
  local custom = status.custom or {}
  
  -- Temperature checks
  if status.temperature then
    if status.temperature >= threshold_set.temp_critical then
      M.createAlert(device_id, device_type, M.SEVERITY.CRITICAL,
        "Critical temperature reached",
        {temperature = status.temperature, threshold = threshold_set.temp_critical})
    elseif status.temperature >= threshold_set.temp_warning then
      M.createAlert(device_id, device_type, M.SEVERITY.WARNING,
        "Temperature warning",
        {temperature = status.temperature, threshold = threshold_set.temp_warning})
    end
  end
  
  -- Energy capacity checks
  if status.energy_capacity > 0 then
    local fill_ratio = status.energy_stored / status.energy_capacity
    
    if fill_ratio <= threshold_set.capacity_critical then
      M.createAlert(device_id, device_type, M.SEVERITY.CRITICAL,
        "Energy capacity critical",
        {stored = status.energy_stored, capacity = status.energy_capacity, ratio = fill_ratio})
    elseif fill_ratio <= threshold_set.capacity_warning then
      M.createAlert(device_id, device_type, M.SEVERITY.WARNING,
        "Energy capacity low",
        {stored = status.energy_stored, capacity = status.energy_capacity, ratio = fill_ratio})
    end
  end
  
  -- Fuel checks (reactors)
  if custom.fuel_amount and custom.fuel_capacity then
    local fuel_ratio = custom.fuel_amount / custom.fuel_capacity
    if fuel_ratio <= threshold_set.fuel_low then
      M.createAlert(device_id, device_type, M.SEVERITY.WARNING,
        "Fuel level low",
        {fuel = custom.fuel_amount, capacity = custom.fuel_capacity, ratio = fuel_ratio})
    end
  end
  
  -- Rotor damage checks
  if custom.shaft_damage and custom.shaft_damage > threshold_set.rotor_damage then
    M.createAlert(device_id, device_type, M.SEVERITY.WARNING,
      "Rotor shaft damage detected",
      {damage = custom.shaft_damage})
  end
  
  -- AE2 CPU warnings
  if custom.online_cpus and custom.total_cpus then
    local offline_cpus = (custom.total_cpus or 0) - (custom.online_cpus or 0)
    if offline_cpus >= threshold_set.cpu_warning then
      M.createAlert(device_id, device_type, M.SEVERITY.WARNING,
        "One or more ME CPUs offline",
        {online = custom.online_cpus, total = custom.total_cpus})
    end
  end
end

-- =============================
-- Alert Broadcasting
-- =============================

function M.broadcast(hmi_channel)
  -- Broadcast all pending alerts to HMI nodes
  if #M.alerts == 0 then return end
  
  hmi_channel = hmi_channel or 1235
  
  modem.broadcast(hmi_channel, serialization.serialize({
    type = "alerts",
    timestamp = os.time(),
    alerts = M.alerts
  }))
end

-- =============================
-- Alert Management
-- =============================

function M.getAlerts(severity)
  if not severity then return M.alerts end
  
  local filtered = {}
  for _, alert in ipairs(M.alerts) do
    if alert.severity == severity then
      table.insert(filtered, alert)
    end
  end
  return filtered
end

function M.getCriticalAlerts()
  return M.getAlerts(M.SEVERITY.CRITICAL)
end

function M.getWarningAlerts()
  return M.getAlerts(M.SEVERITY.WARNING)
end

function M.clearAlerts()
  M.alerts = {}
end

function M.clearOldAlerts(seconds_old)
  -- Remove alerts older than N seconds
  seconds_old = seconds_old or 3600  -- default 1 hour
  local now = os.time()
  
  local remaining = {}
  for _, alert in ipairs(M.alerts) do
    if now - alert.timestamp < seconds_old then
      table.insert(remaining, alert)
    end
  end
  
  M.alerts = remaining
end

function M.getAlertCount()
  return #M.alerts
end

function M.getAlertStats()
  local stats = {
    total = #M.alerts,
    critical = 0,
    warning = 0,
    info = 0
  }
  
  for _, alert in ipairs(M.alerts) do
    if alert.severity == M.SEVERITY.CRITICAL then
      stats.critical = stats.critical + 1
    elseif alert.severity == M.SEVERITY.WARNING then
      stats.warning = stats.warning + 1
    else
      stats.info = stats.info + 1
    end
  end
  
  return stats
end

-- =============================
-- Threshold Management
-- =============================

function M.setThreshold(device_type, threshold_name, value)
  if not M.THRESHOLDS[device_type] then
    M.THRESHOLDS[device_type] = {}
  end
  M.THRESHOLDS[device_type][threshold_name] = value
end

function M.getThreshold(device_type, threshold_name)
  if not M.THRESHOLDS[device_type] then return nil end
  return M.THRESHOLDS[device_type][threshold_name]
end

function M.resetThresholds()
  -- Reset to defaults
  M.THRESHOLDS = {
    br_reactor = {
      temp_critical = 1200,
      temp_warning = 1000,
      fuel_low = 0.1
    },
    br_turbine = {
      rotor_damage = 0.5,
      speed_warning = 1500
    },
    mek_fission = {
      temp_critical = 900,
      temp_warning = 700,
      fuel_low = 0.05
    },
    mek_fusion = {
      temp_critical = 100000000,
      temp_warning = 50000000,
      plasma_too_cold = 5000000
    },
    thermal_energy = {
      capacity_critical = 0.05,
      capacity_warning = 0.2
    },
    mek_energy = {
      capacity_critical = 0.05,
      capacity_warning = 0.2
    },
    enderio_energy = {
      capacity_critical = 0.05,
      capacity_warning = 0.2
    },
    ae2_network = {
      capacity_critical = 0.05,
      capacity_warning = 0.2,
      cpu_warning = 1
    }
  }
end

return M
