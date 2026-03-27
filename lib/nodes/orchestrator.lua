local component = require("component")
local event = require("event")
local internet = require("internet")
local serialization = require("serialization")
local computer = require("computer")
local filesystem = require("filesystem")

local modem = component.modem
local cfg = require("config")
local db = require("database")
local alerts = require("alerts")

-- Ensure branch-aware GitHub base (main/dev)
cfg.github_base = cfg.github_base or "https://raw.githubusercontent.com/Daminer5/OC_BaseOS/refs/heads/main"
cfg.branch = cfg.branch or "dev"
local repoRoot = cfg.github_base:gsub("/(main|dev)$", "")
cfg.github_base = repoRoot .. "/" .. cfg.branch

modem.open(cfg.channel)

-- Dynamic node registry with capabilities
local nodes = {}
local task_assignments = {}  -- Dynamic task assignments

-- helpers
local function download(url)
  local handle = internet.request(url)
  local data = ""
  for chunk in handle do data = data .. chunk end
  return data
end

local function readFile(path)
  if not filesystem.exists(path) then return nil end
  local f = io.open(path, "r")
  if not f then return nil end
  local data = f:read("*a")
  f:close()
  return data
end

local function writeFile(path, data)
  os.execute("mkdir -p " .. path:match("(.*/)") or "/")
  local f = io.open(path,"w")
  f:write(data)
  f:close()
end

-- sync from GitHub (cached)
local manifest = nil
local CURRENT_VERSION = nil
local function sync()
  local remoteVersion = download(cfg.github_base.."/version.txt")
  if CURRENT_VERSION == remoteVersion then return end

  CURRENT_VERSION = remoteVersion
  local manifestData = download(cfg.github_base.."/manifest.lua")
  manifest = load("return "..manifestData)()
  writeFile("/cache/version.txt", CURRENT_VERSION)
  writeFile("/cache/manifest.lua", manifestData)

  for file, _ in pairs(manifest.files) do
    writeFile("/cache/files"..file, download(cfg.github_base..file))
  end
  print("Manifest cached, version "..CURRENT_VERSION)
end

-- =============================
-- Task Assignment & Auto-scaling
-- =============================

local function assignTasks()
  -- Dynamically assign tasks based on node capabilities and load
  -- Priority: spread critical monitoring tasks across available nodes
  
  local critical_tasks = {"reactor_monitor", "storage_monitor", "ae2_monitor", "br_controller"}
  local task_load = {}
  
  -- Count how many nodes are running each task
  for node_id, node in pairs(nodes) do
    for _, task in ipairs(node.tasks or {}) do
      task_load[task] = (task_load[task] or 0) + 1
    end
  end
  
  -- Assign tasks to underutilized nodes
  for _, task_name in ipairs(critical_tasks) do
    if (task_load[task_name] or 0) == 0 then
      -- No node running this task, assign to first available node
      for node_id, node in pairs(nodes) do
        if node.node_type ~= "hmi" and node.last_seen and (os.time() - node.last_seen) < 60 then
          task_assignments[node_id] = task_assignments[node_id] or {}
          table.insert(task_assignments[node_id], task_name)
          break
        end
      end
    elseif (task_load[task_name] or 0) == 1 then
      -- Only one node, try to add redundant monitoring
      local assigned_count = 0
      for node_id, _ in pairs(nodes) do
        if node_id ~= node_id and (task_assignments[node_id] or {})[task_name] == nil then
          if assigned_count < 1 then  -- max 1 redundant
            task_assignments[node_id] = task_assignments[node_id] or {}
            table.insert(task_assignments[node_id], task_name)
            assigned_count = assigned_count + 1
          end
        end
      end
    end
  end
end

-- =============================
-- Message Handler
-- =============================

local function handleMessage(_, _, from, port, _, raw)
  if port ~= cfg.channel then return end
  local ok, msg = pcall(serialization.unserialize, raw)
  if not ok then return end

  if msg.type == "register" then
    nodes[msg.node_id] = {
      node_type = msg.node_type,
      tasks = msg.tasks or {},
      version = msg.version,
      file_hashes = msg.file_hashes or {},
      last_seen = os.time(),
      supported_tasks = msg.supported_tasks or {},
      hardware_profile = msg.hardware_profile or {}
    }
    db.registerNode(msg.node_id, msg.node_type, msg.tasks, msg.version, msg.file_hashes)
    print("Node registered: " .. msg.node_id .. " (" .. msg.node_type .. ")")
  end
  
  if msg.type == "heartbeat" then
    if nodes[msg.node_id] then
      nodes[msg.node_id].version = msg.version
      nodes[msg.node_id].file_hashes = msg.file_hashes or {}
      nodes[msg.node_id].last_seen = os.time()
      nodes[msg.node_id].tasks = msg.tasks or nodes[msg.node_id].tasks
      db.updateHeartbeat(msg.node_id, msg.uptime, msg.version, msg.file_hashes)
    end
  end
  
  if msg.type == "node_status" then
    if nodes[msg.node_id] then
      nodes[msg.node_id].last_status = msg
      nodes[msg.node_id].status = msg.status or nodes[msg.node_id].status
    end
  end

  if msg.type == "sensor_batch" then
    if nodes[msg.node_id] then
      for _, sample in ipairs(msg.data or {}) do
        db.recordSensors(msg.node_id, sample)
      end
      nodes[msg.node_id].last_sensor_push = os.time()
    end
  end

  if msg.type == "ae2_status" then
    -- non-critical AE2 data; store as sensor record in supervisor DB
    local node_id = msg.node_id or "ae_storage"
    for _, net in ipairs(msg.networks or {}) do
      local sample = {
        timestamp = msg.timestamp or os.time(),
        node_id = node_id,
        node_type = "ae_storage",
        metrics = {
          item_types = net.item_count,
          fluid_types = net.fluid_count,
          item_storage_used = net.item_used,
          item_storage_capacity = net.item_capacity,
          fluid_storage_used = net.fluid_used,
          fluid_storage_capacity = net.fluid_capacity,
          item_pct = net.item_pct,
          fluid_pct = net.fluid_pct
        }
      }
      db.recordSensors(node_id, sample)
    end
  end

  if msg.type == "delta_request" and manifest then
    local response = {type="delta_response", files={}}
    for _, file in ipairs(msg.files) do
      local data = readFile("/cache/files"..file)
      if data then response.files[file] = data end
    end
    modem.send(from, cfg.channel, serialization.serialize(response))
  end

  if msg.type == "manifest_request" then
    modem.send(from, cfg.channel, serialization.serialize({
      type="manifest_response",
      manifest = readFile("/cache/manifest.lua")
    }))
  end
  
  if msg.type == "task_request" then
    -- Node requesting task assignments
    local assigned = task_assignments[msg.node_id] or {}
    modem.send(from, cfg.channel, serialization.serialize({
      type = "task_assignment",
      node_id = msg.node_id,
      tasks = assigned
    }))
  end
end

db.load()

event.listen("modem_message", handleMessage)

local scram_engaged = false
local critical_reactors = {de_reactor=true, mekanism_fission_reactor=true, ic2_reactor=true}

local function dispatchScram(reason)
  if scram_engaged then return end
  scram_engaged = true
  print("!!! SCRAM engaged: "..reason)
  -- broadcast SCRAM notice
  modem.broadcast(cfg.channel, serialization.serialize({
    type = "scram",
    reason = reason,
    timestamp = os.time()
  }))
  alerts.createAlert("supervisor", "scram", alerts.SEVERITY.CRITICAL,
    "SCRAM engaged due to "..reason,
    {reason=reason})
end

local function checkNodeHealth()
  local now = os.time()
  for node_id, node in pairs(db.nodes) do
    local age = now - (node.last_heartbeat or 0)
    local allowed = 3
    if critical_reactors[node.node_type] then
      allowed = 2
    end

    if age > allowed then
      node.status = "mia"
      node.missed_heartbeats = (node.missed_heartbeats or 0) + 1

      if critical_reactors[node.node_type] then
        dispatchScram("critical reactor node MIA: "..node_id)
      elseif node.missed_heartbeats >= 3 then
        dispatchScram("node MIA: "..node_id)
      end
    else
      node.status = "online"
      node.missed_heartbeats = 0
    end

    -- DE reactor explicit failure condition
    if node.node_type == "de_reactor" and node.status == "mia" then
      local hist = db.getSensorHistory(node_id, 30)
      local last = hist[#hist]
      if last and last.metrics and last.metrics.de_reactor and (last.metrics.de_reactor.energy_output or 0) == 0 then
        alerts.createAlert(node_id, "de_reactor", alerts.SEVERITY.CRITICAL,
          "DE reactor is SCRAM+no power draw; assumed explosion (kaboom).", {})
      end
    end
  end
end

-- main loop
local lastSync = 0
local lastTaskAssignment = 0

while true do
  local now = computer.uptime()
  
  if now - lastSync > cfg.sync_interval then
    pcall(sync)
    lastSync = now
  end
  
  -- Periodically reassign tasks (every 60 seconds)
  if now - lastTaskAssignment > 60 then
    pcall(assignTasks)
    lastTaskAssignment = now
  end

  -- health checks for all nodes
  db.updateStaleness()
  checkNodeHealth()

  -- broadcast current version to all nodes
  for node_id, node in pairs(nodes) do
    -- Only broadcast to nodes seen in last 2 minutes
    if node.last_seen and (os.time() - node.last_seen) < 120 then
      modem.broadcast(cfg.channel, serialization.serialize({
        type = "version_announce",
        version = CURRENT_VERSION,
        node_id = node_id,
        assigned_tasks = task_assignments[node_id] or {}
      }))
    end
  end
  
  -- Clean up stale node entries (older than 1 hour)
  local now_time = os.time()
  for node_id, node in pairs(nodes) do
    if node.last_seen and (now_time - node.last_seen) > 3600 then
      nodes[node_id] = nil
    end
  end

  -- Database persistence and pruning
  db.autoSave()
  db.pruneAllSensorHistory(300)
  alerts.clearOldAlerts(3600)

  os.sleep(1)
end