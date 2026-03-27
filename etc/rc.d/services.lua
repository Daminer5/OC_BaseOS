-- Node Service Launcher
-- Main rc.d service that invokes the kickstarter

local function log(msg)
  io.write("[services] " .. msg .. "\n")
end

function start()
  log("Starting node services...")
  
  -- Check if kickstart already ran
  if _G.node_services_started then
    log("Services already started in this session")
    return
  end
  
  -- Call kickstarter
  local shell = require("shell")
  local result = shell.execute("kickstart.lua")
  
  if result == 0 then
    _G.node_services_started = true
    log("Node services started successfully")
  else
    log("Failed to start node services (exit code: " .. tostring(result) .. ")")
  end
end

function stop()
  log("Stopping node services...")
  _G.node_services_started = false
  log("Services marked for shutdown")
end

function status()
  if _G.node_services_started then
    log("Services: RUNNING")
    return 0
  else
    log("Services: STOPPED")
    return 1
  end
end

-- Start services on load if not in debug mode
if not args or args ~= "--debug" then
  start()
end
