-- Exporter Node Service Control

local function log(msg)
  io.write("[exporter-service] " .. msg .. "\n")
end

function start()
  log("Starting Exporter services...")
  local shell = require("shell")
  local result = shell.execute("kickstart.lua exporter")
  return result
end

function stop()
  log("Stopping Exporter services...")
end

function status()
  if _G.exporter_node_running then
    log("Status: RUNNING")
    return 0
  else
    log("Status: STOPPED")
    return 1
  end
end

function restart()
  log("Restarting Exporter services...")
  stop()
  return start()
end
