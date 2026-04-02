-- Exporter Node for InfluxDB telemetry upload
-- Supervisory exporter for time-series data from node database

local component = require("component")
local event = require("event")
local internet = require("internet")
local serialization = require("serialization")
local computer = require("computer")

local db = require("database")
local alerts = require("alerts")
local cfg = require("/lib/nodes/config/exporter")
local hal = require("/lib/hardware/hal")

local exporter = {}
exporter.name = "exporter"
exporter.version = "1.1.0"
exporter.description = "Exporter to forward telemetry to InfluxDB"

local function ensureConfig()
  cfg.influx = cfg.influx or {}
  cfg.influx.url = cfg.influx.url or "http://localhost:8086/write"
  cfg.influx.db = cfg.influx.db or "oc_baseos"
  cfg.influx.user = cfg.influx.user or ""
  cfg.influx.pass = cfg.influx.pass or ""
  cfg.flush_interval = cfg.influx.flush_interval or 5
end

local function writeInfluxLine(node_id, measurement, fields, tags, ts)
  local tag_str = "node=" .. node_id
  for k, v in pairs(tags or {}) do
    tag_str = tag_str .. "," .. k .. "=" .. tostring(v)
  end

  local field_parts = {}
  for k, v in pairs(fields) do
    local value = v
    if type(v) == "string" then
      value = string.format('"%s"', tostring(v))
    elseif type(v) == "boolean" then
      value = tostring(v)
    else
      value = tostring(v)
    end
    table.insert(field_parts, k .. "=" .. value)
  end

  local line = measurement .. "," .. tag_str .. " " .. table.concat(field_parts, ",")
  if ts then
    line = line .. " " .. tostring(ts)
  end
  return line
end

local function exportToInflux()
  local now = os.time()

  if not cfg.influx.url or not cfg.influx.db then
    return false, "InfluxDB URL/db not configured"
  end

  local payload_lines = {}

  for _, node in ipairs(db.getAllNodes()) do
    local history = db.getSensorHistory(node.node_id, 300)
    for _, sample in ipairs(history) do
      local tag = {node_type = node.node_type or "unknown"}
      local fields = {
        uptime = sample.metrics.uptime or 0,
        free_memory = sample.metrics.free_memory or 0,
        total_memory = sample.metrics.total_memory or 0,
        cpu_load = sample.metrics.cpu_load or 0
      }

      local line = writeInfluxLine(node.node_id, "base_node_metrics", fields, tag, math.floor(sample.timestamp * 1e9))
      table.insert(payload_lines, line)

      for service, specs in pairs(sample.metrics) do
        if service ~= "uptime" and service ~= "free_memory" and service ~= "total_memory" and service ~= "cpu_load" then
          for k, v in pairs(specs) do
            if type(v) == "number" then
              local l = writeInfluxLine(node.node_id, "sensor_"..service, {[k]=v}, tag, math.floor(sample.timestamp * 1e9))
              table.insert(payload_lines, l)
            end
          end
        end
      end
    end
  end

  if #payload_lines == 0 then
    return true
  end

  local query = "?db="..cfg.influx.db
  if cfg.influx.user ~= "" and cfg.influx.pass ~= "" then
    query = query .. "&u=" .. cfg.influx.user .. "&p=" .. cfg.influx.pass
  end
  local url = cfg.influx.url .. query
  local response = internet.request(url, table.concat(payload_lines, "\n"))
  if not response then
    alerts.createAlert("exporter", "influx", alerts.SEVERITY.WARNING, "InfluxDB write failed", {url=url})
    return false, "no response"
  end

  -- consume and drop response body
  for chunk in response do end
  return true
end

function exporter.init()
  ensureConfig()
  db.load()
  return true
end

function exporter.run()
  local last_flush = computer.uptime()
  while true do
    if computer.uptime() - last_flush >= (cfg.influx.flush_interval or 5) then
      local ok, err = exportToInflux()
      if not ok then
        alerts.createAlert("exporter", "influx", alerts.SEVERITY.WARNING, "Failed to export InfluxDB data", {error=err})
      end
      last_flush = computer.uptime()
    end
    os.sleep(1)
  end
end

-- Shutdown exporter
function exporter.shutdown()
  print("[Exporter] Shutting down")
  hal.cleanup()
end

return exporter
