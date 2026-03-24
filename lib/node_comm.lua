local component = require("component")
local serialization = require("serialization")
local computer = require("computer")
local event = require("event")

local modem = component.modem
local cfg = require("config")

modem.open(cfg.orchestrator_channel)

local node_comm = {}
node_comm.last_heartbeat = 0
node_comm.heartbeat_interval = 30  -- seconds

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
  if now - node_comm.last_heartbeat < node_comm.heartbeat_interval then return end

  modem.broadcast(cfg.orchestrator_channel, serialization.serialize({
    type = "heartbeat",
    node_id = cfg.node_id,
    uptime = computer.uptime(),
    version = cfg.version,
    file_hashes = cfg.file_hashes or {}
  }))

  node_comm.last_heartbeat = now
end

-- initialize
register()

return node_comm