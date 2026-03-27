local component = require("component")
local serialization = require("serialization")
local computer = require("computer")
local event = require("event")

local modem = component.modem
local cfg = require("config")

modem.open(cfg.orchestrator_channel)

local node_comm = {}
node_comm.last_heartbeat = 0
node_comm.heartbeat_interval = 1 -- heartbeat every second
node_comm.sensor_buffer = {}
node_comm.last_sensor_send = computer.uptime()
node_comm.sensor_interval = 3 -- send 3 seconds data every 3 seconds
node_comm.missed_heartbeats = 0

local function collectSensors()
  local sensors = {
    timestamp = computer.uptime(),
    node_id = cfg.node_id,
    node_type = cfg.node_type,
    services = cfg.tasks or {},
    metrics = {
      uptime = computer.uptime(),
      free_memory = computer.freeMemory(),
      total_memory = computer.totalMemory(),
      cpu_load = computer.uptime() > 0 and (computer.freeMemory() / computer.totalMemory()) or 0,
    },
    components = {}
  }

  -- Generic component health
  for address, ctype in component.list() do
    sensors.components[address] = {type = ctype}
  end

  -- Service-specific sensors
  local function serviceSensor(name)
    if name == "br_reactor" then
      if component.isAvailable("br_reactor") then
        local r = component.br_reactor
        sensors.metrics.br_reactor = {
          active = r.getActive(),
          temperature = r.getTemperature(),
          fuel_amount = r.getFuelAmount(),
          fuel_burn_rate = r.getFuelBurnRate(),
          energy_output = r.getEnergyProducedLastTick()
        }
      end
    elseif name == "mekanism_fission_reactor" then
      if component.isAvailable("mekanism_fission_reactor") then
        local m = component.mekanism_fission_reactor
        sensors.metrics.mekanism_fission_reactor = {
          active = m.getActive(),
          temperature = m.getTemperature(),
          efficiency = m.getEfficiency(),
          energy_output = m.getEnergyProducedLastTick()
        }
      end
    elseif name == "de_reactor" then
      if component.isAvailable("de_reactor") then
        local d = component.de_reactor
        sensors.metrics.de_reactor = {
          active = d.getActive(),
          containment = d.getContainmentFieldEnergy(),
          energy_output = d.getEnergyProducedLastTick(),
          fuel_amount = d.getFuelAmount()
        }
      end
    elseif name == "ic2_reactor" then
      if component.isAvailable("ic2_reactor") then
        local i = component.ic2_reactor
        sensors.metrics.ic2_reactor = {
          active = i.getActive(),
          heat = i.getHeatLevel(),
          energy_output = i.getEnergyProducedLastTick(),
          fuel_amount = i.getFuelAmount()
        }
      end
    elseif name == "ae_monitor" or name == "ae_storage" then
      if component.isAvailable("me_controller") or component.isAvailable("me_monitor") or component.isAvailable("me_interface") then
        local ae2_modules = require("hardware.ae2_monitor")
        local device_addr = nil
        for addr, ctype in component.list("me_") do
          if ctype:find("controller") or ctype:find("monitor") or ctype == "me_interface" then
            device_addr = addr
            break
          end
        end

        if device_addr then
          local ae2_dev = ae2_modules.new(device_addr)
          local status = ae2_dev:getStatus()
          if status and status.custom then
            sensors.metrics.ae2 = {
              item_types = status.custom.item_types,
              fluid_types = status.custom.fluid_types,
              item_storage_used = status.custom.item_storage_used,
              item_storage_capacity = status.custom.item_storage_capacity,
              fluid_storage_used = status.custom.fluid_storage_used,
              fluid_storage_capacity = status.custom.fluid_storage_capacity
            }
          end
        end
      end
    end
  end

  for _, service in ipairs(cfg.tasks or {}) do
    serviceSensor(service)
  end

  return sensors
end

local function sendSensorBatch()
  if #node_comm.sensor_buffer < node_comm.sensor_interval then return end

  local payload = {
    type = "sensor_batch",
    node_id = cfg.node_id,
    node_type = cfg.node_type,
    data = node_comm.sensor_buffer,
    timestamp = computer.uptime()
  }

  modem.broadcast(cfg.orchestrator_channel, serialization.serialize(payload))
  node_comm.sensor_buffer = {}
  node_comm.last_sensor_send = computer.uptime()
end

-- send registration on boot
local function register()
  modem.broadcast(cfg.orchestrator_channel, serialization.serialize({
    type = "register",
    node_id = cfg.node_id,
    node_type = cfg.node_type,
    tasks = cfg.tasks,
    version = cfg.version,
    file_hashes = cfg.file_hashes or {}
  }))
end

-- heartbeat to update orchestrator with status
function node_comm.heartbeat()
  local now = computer.uptime()

  -- sensor snapshot every second
  local sensor = collectSensors()
  table.insert(node_comm.sensor_buffer, sensor)

  -- send sensor data packet every 3 seconds
  if now - node_comm.last_sensor_send >= node_comm.sensor_interval then
    sendSensorBatch()
  end

  -- heartbeat message
  modem.broadcast(cfg.orchestrator_channel, serialization.serialize({
    type = "heartbeat",
    node_id = cfg.node_id,
    uptime = now,
    version = cfg.version,
    file_hashes = cfg.file_hashes or {},
    tasks = cfg.tasks or {},
    last_sensor = sensor
  }))

  node_comm.last_heartbeat = now
end

-- Connection check and failover
function node_comm.checkSupervisorReachable()
  -- This can be used by nodes controlling reactors to force shutdown when supervisor is unreachable.
  local pingMessage = serialization.serialize({type = "supervisor_ping", node_id = cfg.node_id, ts = computer.uptime()})
  modem.broadcast(cfg.orchestrator_channel, pingMessage)
  return true
end

-- initialize
register()

return node_comm