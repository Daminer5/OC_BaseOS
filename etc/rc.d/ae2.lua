-- AE2 Storage Monitor Node Service Control

local function log(msg)
  io.write("[ae2-service] " .. msg .. "\n")
end

function start()
  log("Starting AE2 Storage Monitor services...")
  local shell = require("shell")
  local result = shell.execute("kickstart.lua ae_storage")
  return result
end

function stop()
  log("Stopping AE2 services...")
end

function status()
  if _G.ae2_node_running then
    log("Status: RUNNING")
    return 0
  else
    log("Status: STOPPED")
    return 1
  end
end

function restart()
  log("Restarting AE2 services...")
  stop()
  return start()
end
