#!/usr/bin/env lua
-- Service Kickstarter
-- Initializes and starts node services after installation or at startup
-- Usage: kickstart.lua [node-type] [root-path]

local component = require("component")
local filesystem = require("filesystem")
local computer = require("computer")
local event = require("event")
local serialization = require("serialization")

local function log(msg, level)
  level = level or "INFO"
  io.write("[kickstarter] [" .. level .. "] " .. msg .. "\n")
end

-- Start message
log("Node Service Kickstarter starting...")
log("System uptime: " .. computer.uptime() .. "s")

-- ============= CONFIGURATION ============= 

local SERVICE_CONFIG = {
  hmi = {
    name = "HMI Dashboard",
    essential = true,
    services = {
      "modem",      -- Network communication
      "monitor",    -- Display/GPU
      "hmi",        -- Main HMI interface
    },
    timeout = 10,
    description = "Human Machine Interface node"
  },
  
  supervisor = {
    name = "Supervisor/Orchestrator",
    essential = true,
    services = {
      "modem",      -- Network communication
      "database",   -- Central database
      "alerts",     -- Alert system
      "orchestrator", -- Main orchestration
    },
    timeout = 15,
    description = "Supervisor and orchestration node"
  },
  
  br_reactor = {
    name = "Big Reactor Controller",
    essential = true,
    services = {
      "modem",      -- Network communication
      "reactor",    -- Reactor control
      "monitor",    -- Monitoring/display
    },
    timeout = 10,
    description = "Big Reactor control and monitoring node"
  },
  
  mekanism_reactor = {
    name = "Mekanism Reactor Controller",
    essential = true,
    services = {
      "modem",      -- Network communication
      "mekanism",   -- Mekanism control
      "monitor",    -- Monitoring/display
    },
    timeout = 10,
    description = "Mekanism reactor control node"
  },
  
  ae_storage = {
    name = "AE2 Storage Monitor",
    essential = false,
    services = {
      "modem",      -- Network communication
      "ae_monitor", -- AE2 monitoring
    },
    timeout = 8,
    description = "Applied Energistics 2 storage monitoring node"
  },
  
  exporter = {
    name = "Export Automation",
    essential = false,
    services = {
      "modem",      -- Network communication
      "exporter",   -- Export control
      "monitor",    -- Status display
    },
    timeout = 10,
    description = "InfluxDB data exporter"
  },
  
  worker = {
    name = "Worker Node",
    essential = false,
    services = {
      "modem",      -- Network communication
      "worker",     -- Worker tasks
    },
    timeout = 8,
    description = "Generic worker node for distributed tasks"
  },
  
  generic = {
    name = "Generic Node",
    essential = false,
    services = {
      "modem",      -- Network communication
    },
    timeout = 5,
    description = "Generic fallback node configuration"
  },
}

-- ============= CORE SERVICES ============= 

local CORE_SERVICES = {
  modem = {
    name = "Network Modem",
    priority = 1,
    check = function()
      return component.isAvailable("modem")
    end,
    init = function(config)
      local modem = component.modem
      modem.open(1234)  -- Default port for node communication
      log("Modem initialized on port 1234")
      return true
    end,
    cleanup = function()
      if component.isAvailable("modem") then
        component.modem.close(1234)
      end
    end
  },
  
  monitor = {
    name = "Monitor/Display",
    priority = 2,
    check = function()
      return component.isAvailable("gpu") and component.isAvailable("screen")
    end,
    init = function(config)
      local gpu = component.gpu
      local w, h = gpu.maxResolution()
      gpu.setResolution(w, h)
      log("Display initialized: " .. w .. "x" .. h)
      return true
    end,
    cleanup = function()
      -- Keep display active
    end
  },
  
  database = {
    name = "Central Database",
    priority = 3,
    check = function()
      return filesystem.exists("/lib/database.lua")
    end,
    init = function(config)
      local ok, db = pcall(require, "/lib/database.lua")
      if ok and db then
        if db.init then db.init(config) end
        log("Database service initialized")
        return true
      end
      return false
    end,
    cleanup = function()
      -- Database cleanup handled by service
    end
  },
  
  alerts = {
    name = "Alert System",
    priority = 4,
    check = function()
      return filesystem.exists("/lib/alerts.lua")
    end,
    init = function(config)
      local ok, alerts = pcall(require, "/lib/alerts.lua")
      if ok and alerts then
        if alerts.init then alerts.init(config) end
        log("Alert system initialized")
        return true
      end
      return false
    end,
    cleanup = function()
      -- Alert cleanup handled by service
    end
  },
  
  reactor = {
    name = "Reactor Controller",
    priority = 5,
    check = function()
      return filesystem.exists("/lib/hardware/br_reactor.lua")
    end,
    init = function(config)
      local ok, reactor = pcall(require, "/lib/hardware/br_reactor.lua")
      if ok and reactor then
        if reactor.init then reactor.init(config) end
        log("Reactor controller initialized")
        return true
      end
      return false
    end,
    cleanup = function()
      -- Reactor cleanup handled by service
    end
  },
  
  mekanism = {
    name = "Mekanism Controller",
    priority = 5,
    check = function()
      return filesystem.exists("/lib/hardware/mekanism_fission.lua") or
             filesystem.exists("/lib/hardware/mekanism_fusion.lua")
    end,
    init = function(config)
      local loaded = false
      if filesystem.exists("/lib/hardware/mekanism_fission.lua") then
        local ok, fission = pcall(require, "/lib/hardware/mekanism_fission.lua")
        if ok and fission and fission.init then
          fission.init(config)
          loaded = true
        end
      end
      if filesystem.exists("/lib/hardware/mekanism_fusion.lua") then
        local ok, fusion = pcall(require, "/lib/hardware/mekanism_fusion.lua")
        if ok and fusion and fusion.init then
          fusion.init(config)
          loaded = true
        end
      end
      if loaded then
        log("Mekanism controller initialized")
      end
      return loaded
    end,
    cleanup = function()
      -- Mekanism cleanup handled by service
    end
  },
  
  ae_monitor = {
    name = "AE2 Monitor",
    priority = 5,
    check = function()
      return filesystem.exists("/lib/hardware/ae2_monitor.lua")
    end,
    init = function(config)
      local ok, ae2 = pcall(require, "/lib/hardware/ae2_monitor.lua")
      if ok and ae2 then
        if ae2.init then ae2.init(config) end
        log("AE2 monitor initialized")
        return true
      end
      return false
    end,
    cleanup = function()
      -- AE2 cleanup handled by service
    end
  },
  
  hmi = {
    name = "HMI Interface",
    priority = 10,
    check = function()
      return filesystem.exists("/lib/nodes/hmi.lua")
    end,
    init = function(config)
      local ok, hmi = pcall(require, "/lib/nodes/hmi.lua")
      if ok and hmi then
        if hmi.init then
          hmi.init()
        end
        log("HMI interface initialized")
        return true
      end
      return false
    end,
    cleanup = function()
      -- HMI cleanup handled by service
    end
  },
  
  orchestrator = {
    name = "Orchestrator Service",
    priority = 10,
    check = function()
      return filesystem.exists("/lib/nodes/orchestrator.lua")
    end,
    init = function(config)
      local ok, orch = pcall(require, "/lib/nodes/orchestrator.lua")
      if ok and orch then
        if orch.init then orch.init() end
        log("Orchestrator service initialized")
        return true
      end
      return false
    end,
    cleanup = function()
      -- Orchestrator cleanup handled by service
    end
  },
  
  exporter = {
    name = "Exporter Service",
    priority = 9,
    check = function()
      return filesystem.exists("/lib/nodes/exporter.lua")
    end,
    init = function(config)
      local ok, exp = pcall(require, "/lib/nodes/exporter.lua")
      if ok and exp then
        if exp.init then exp.init() end
        log("Exporter service initialized")
        return true
      end
      return false
    end,
    cleanup = function()
      -- Exporter cleanup handled by service
    end
  },
  
  worker = {
    name = "Worker Service",
    priority = 8,
    check = function()
      return component.isAvailable("modem")  -- Just need modem for worker
    end,
    init = function(config)
      log("Worker service initialized")
      return true
    end,
    cleanup = function()
      -- Worker cleanup handled by service
    end
  },
}

-- ============= DETECTION AND INITIALIZATION ============= 

local function detectNodeType()
  log("Detecting node type from hardware...")
  
  local hw = {
    modem = component.isAvailable("modem"),
    gpu = component.isAvailable("gpu"),
    screen = component.isAvailable("screen"),
    reactor = false,
    ae2 = false,
    storage = false,
  }
  
  -- Scan for components
  for address, ctype in component.list() do
    if ctype:find("[Rr]eactor") then
      hw.reactor = true
    elseif ctype:find("me_") then
      hw.ae2 = true
    elseif ctype:find("[Ee]nder[IO]") or ctype:find("[Tt]hermal") or ctype:find("[Mm]ekanism") then
      hw.storage = true
    end
  end
  
  log("Hardware detected: modem=" .. tostring(hw.modem) .. ", gpu=" .. tostring(hw.gpu) ..
      ", reactor=" .. tostring(hw.reactor) .. ", ae2=" .. tostring(hw.ae2))
  
  -- Recommend node type
  if hw.gpu and hw.screen then return "hmi", "GPU+Screen detected" end
  if hw.reactor then return "br_reactor", "Reactor detected" end
  if hw.ae2 then return "ae_storage", "AE2 system detected" end
  if hw.modem then return "worker", "Modem detected" end
  
  return "generic", "No specific hardware detected"
end

local function getNodeType()
  local nodeTypeFile = "/etc/node_type"
  
  -- Check if node type is saved
  if filesystem.exists(nodeTypeFile) then
    local f = io.open(nodeTypeFile, "r")
    if f then
      local nodeType = f:read("*line"):gsub("^%s+|%s+$", "")
      f:close()
      if nodeType and nodeType ~= "" then
        log("Node type loaded from file: " .. nodeType)
        return nodeType
      end
    end
  end
  
  -- Auto-detect
  local nodeType, reason = detectNodeType()
  log("Auto-detected: " .. nodeType .. " (" .. reason .. ")")
  
  return nodeType
end

local function saveNodeType(nodeType)
  local nodeTypeFile = "/etc/node_type"
  local dir = nodeTypeFile:match("(.*/)")
  if dir and not filesystem.exists(dir) then
    filesystem.makeDirectory(dir)
  end
  
  local f = io.open(nodeTypeFile, "w")
  if f then
    f:write(nodeType .. "\n")
    f:close()
    log("Node type saved: " .. nodeType)
  end
end

local function loadConfig(nodeType)
  local configPath = "/etc/" .. nodeType .. ".cfg"
  
  if filesystem.exists(configPath) then
    local f = io.open(configPath, "r")
    if f then
      local content = f:read("*a")
      f:close()
      local ok, cfg = pcall(load, content)
      if ok and type(cfg) == "function" then
        ok, cfg = pcall(cfg)
        if ok and type(cfg) == "table" then
          log("Configuration loaded from: " .. configPath)
          return cfg
        end
      end
    end
  end
  
  return {}
end

-- ============= SERVICE MANAGEMENT ============= 

local started_services = {}

local function startService(serviceName, config)
  if started_services[serviceName] then
    log("Service already started: " .. serviceName, "DEBUG")
    return true
  end
  
  local service = CORE_SERVICES[serviceName]
  if not service then
    log("Unknown service: " .. serviceName, "WARN")
    return false
  end
  
  log("Starting service: " .. service.name)
  
  -- Check prerequisites
  if not service.check() then
    log("Service check failed for: " .. serviceName, "WARN")
    return false
  end
  
  -- Initialize service
  local ok, err = pcall(service.init, config)
  if not ok or not err then
    log("Failed to initialize " .. serviceName .. ": " .. tostring(err or "unknown error"), "ERROR")
    return false
  end
  
  started_services[serviceName] = true
  log("✓ Service started: " .. service.name)
  return true
end

local function startNodeServices(nodeType, config)
  local nodeConfig = SERVICE_CONFIG[nodeType]
  
  if not nodeConfig then
    log("Unknown node type: " .. nodeType, "ERROR")
    return false
  end
  
  log("Initializing node: " .. nodeConfig.name)
  log("Type: " .. nodeType)
  log("Description: " .. nodeConfig.description)
  log("Starting " .. #nodeConfig.services .. " services...")
  
  -- Sort services by priority
  local services = {}
  for _, svcName in ipairs(nodeConfig.services) do
    local svc = CORE_SERVICES[svcName]
    if svc then
      table.insert(services, {name = svcName, priority = svc.priority})
    end
  end
  
  table.sort(services, function(a, b) return a.priority < b.priority end)
  
  -- Start services in priority order
  local failed = {}
  for _, svc in ipairs(services) do
    if not startService(svc.name, config) then
      table.insert(failed, svc.name)
      if CORE_SERVICES[svc.name].essential then
        log("Essential service failed: " .. svc.name, "ERROR")
        return false
      end
    end
  end
  
  if #failed > 0 then
    log("Some services failed to start: " .. table.concat(failed, ", "), "WARN")
  end
  
  log("Node initialization complete!")
  return true
end

-- ============= MAIN EXECUTION ============= 

local function main()
  local args = {...}
  local nodeType = args[1]
  
  -- If no node type provided, detect it
  if not nodeType or nodeType == "" then
    nodeType = getNodeType()
  else
    log("Node type specified: " .. nodeType)
    saveNodeType(nodeType)
  end
  
  -- Load configuration
  local config = loadConfig(nodeType)
  
  -- Start services
  if startNodeServices(nodeType, config) then
    log("=====================================================")
    log("Node services started successfully!")
    log("Node Type: " .. nodeType)
    log("Uptime: " .. computer.uptime() .. "s")
    log("=====================================================")
    return 0
  else
    log("=====================================================", "ERROR")
    log("Failed to start critical services!", "ERROR")
    log("Node Type: " .. nodeType, "ERROR")
    log("=====================================================", "ERROR")
    return 1
  end
end

-- Register cleanup on shutdown
event.listen("shutdown", function()
  log("Shutting down services...")
  for serviceName, _ in pairs(started_services) do
    local service = CORE_SERVICES[serviceName]
    if service and service.cleanup then
      pcall(service.cleanup)
    end
  end
  log("Services shut down")
  return false
end)

-- Run main
return main(...)
