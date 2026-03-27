-- Mekanism Reactor Node Service Control

local function log(msg)
  io.write("[mekanism-service] " .. msg .. "\n")
end

function start()
  log("Starting Mekanism Reactor services...")
  local shell = require("shell")
  local result = shell.execute("kickstart.lua mekanism_reactor")
  return result
end

function stop()
  log("Stopping Mekanism Reactor services...")
end

function status()
  if _G.mekanism_node_running then
    log("Status: RUNNING")
    return 0
  else
    log("Status: STOPPED")
    return 1
  end
end

function restart()
  log("Restarting Mekanism Reactor services...")
  stop()
  return start()
end
