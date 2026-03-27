-- Big Reactor Node Service Control

local function log(msg)
  io.write("[reactor-service] " .. msg .. "\n")
end

function start()
  log("Starting Big Reactor services...")
  local shell = require("shell")
  local result = shell.execute("kickstart.lua br_reactor")
  return result
end

function stop()
  log("Stopping Big Reactor services...")
end

function status()
  if _G.reactor_node_running then
    log("Status: RUNNING")
    return 0
  else
    log("Status: STOPPED")
    return 1
  end
end

function restart()
  log("Restarting Big Reactor services...")
  stop()
  return start()
end
