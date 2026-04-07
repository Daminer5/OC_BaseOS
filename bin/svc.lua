#!/usr/bin/env lua
-- Service Management Utility
-- Usage: svc [command] [service-name]
-- Commands: start, stop, restart, status, list, reload

local shell = require("shell")
local filesystem = require("filesystem")

local SERVICES_DIR = "/etc/rc.d"

local COMMANDS = {
  start = "Start a service",
  stop = "Stop a service",
  restart = "Restart a service",
  status = "Check service status",
  list = "List all available services",
  reload = "Reload all services",
}

local function log(msg, level)
  level = level or "INFO"
  io.write("[svc] [" .. level .. "] " .. msg .. "\n")
end

local function listServices()
  log("Available services:")
  
  local services = {}
  for file in filesystem.list(SERVICES_DIR) do
    if file:endsWith(".lua") and file ~= "example.lua" then
      table.insert(services, file:gsub("%.lua$", ""))
    end
  end
  
  table.sort(services)
  
  if #services == 0 then
    log("No services found", "WARN")
    return
  end
  
  for _, svc in ipairs(services) do
    io.write("  - " .. svc .. "\n")
  end
end

local function loadService(serviceName)
  local servicePath = SERVICES_DIR .. "/" .. serviceName .. ".lua"
  
  if not filesystem.exists(servicePath) then
    log("Service not found: " .. serviceName, "ERROR")
    return nil
  end
  
  local env = setmetatable({}, {__index = _G})
  local fn, err = loadfile(servicePath, 't', env)
  
  if not fn then
    log("Failed to load service: " .. err, "ERROR")
    return nil
  end
  
  local ok, err = pcall(fn)
  if not ok then
    log("Failed to execute service: " .. err, "ERROR")
    return nil
  end
  
  return env
end

local function executeCommand(command, serviceName)
  local service = loadService(serviceName)
  
  if not service then
    return 1
  end
  
  local cmdFunc = service[command]
  if not cmdFunc or type(cmdFunc) ~= "function" then
    log("Command not supported by service: " .. command, "WARN")
    return 1
  end
  
  log("Executing '" .. command .. "' on service '" .. serviceName .. "'")
  
  local ok, result = pcall(cmdFunc)
  
  if not ok then
    log("Command failed: " .. tostring(result), "ERROR")
    return 1
  end
  
  return result or 0
end

local function main()
  local args = shell.parse()
  
  if #args == 0 then
    io.write("Service Management Utility\n")
    io.write("Usage: svc [command] [service-name]\n")
    io.write("\nCommands:\n")
    for cmd, desc in pairs(COMMANDS) do
      io.write("  " .. cmd .. "\t- " .. desc .. "\n")
    end
    io.write("\nExamples:\n")
    io.write("  svc list\n")
    io.write("  svc start supervisor\n")
    io.write("  svc restart hmi\n")
    return 0
  end
  
  local command = args[1]
  
  if command == "list" then
    listServices()
    return 0
  elseif command == "reload" then
    log("Reloading all services")
    local services = {}
    for file in filesystem.list(SERVICES_DIR) do
      if file:endsWith(".lua") and file ~= "example.lua" then
        table.insert(services, file:gsub("%.lua$", ""))
      end
    end
    
    local failed = {}
    for _, svc in ipairs(services) do
      if executeCommand("restart", svc) ~= 0 then
        table.insert(failed, svc)
      end
    end
    
    if #failed > 0 then
      log("Some services failed to reload: " .. table.concat(failed, ", "), "WARN")
      return 1
    end
    return 0
  else
    if #args < 2 then
      log("Missing service name", "ERROR")
      return 1
    end
    
    local serviceName = args[2]
    
    if not COMMANDS[command] then
      log("Unknown command: " .. command, "ERROR")
      return 1
    end
    
    return executeCommand(command, serviceName)
  end
end

return main(...)
