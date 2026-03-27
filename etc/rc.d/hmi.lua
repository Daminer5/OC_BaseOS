-- HMI Node Service Control

local function log(msg)
  io.write("[hmi-service] " .. msg .. "\n")
end

function start()
  log("Starting HMI node services...")
  local shell = require("shell")
  local result = shell.execute("kickstart.lua hmi")
  return result
end

function stop()
  log("Stopping HMI node services...")
  -- Services cleanup will be handled by shutdown event
end

function status()
  if _G.hmi_node_running then
    log("Status: RUNNING")
    return 0
  else
    log("Status: STOPPED")
    return 1
  end
end

function restart()
  log("Restarting HMI node services...")
  stop()
  return start()
end
