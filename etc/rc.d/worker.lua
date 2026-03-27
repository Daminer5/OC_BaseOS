-- Worker Node Service Control

local function log(msg)
  io.write("[worker-service] " .. msg .. "\n")
end

function start()
  log("Starting Worker Node services...")
  local shell = require("shell")
  local result = shell.execute("kickstart.lua worker")
  return result
end

function stop()
  log("Stopping Worker services...")
end

function status()
  if _G.worker_node_running then
    log("Status: RUNNING")
    return 0
  else
    log("Status: STOPPED")
    return 1
  end
end

function restart()
  log("Restarting Worker services...")
  stop()
  return start()
end
