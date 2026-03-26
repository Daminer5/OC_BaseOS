local component = require("component")
local event = require("event")
local internet = require("internet")
local serialization = require("serialization")
local computer = require("computer")
local filesystem = require("filesystem")

local modem = component.modem
local cfg = require("config")

-- Ensure branch-aware GitHub base (main/dev)
cfg.github_base = cfg.github_base or "https://raw.githubusercontent.com/Daminer5/OC_BaseOS/main"
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
  
  local critical_tasks = {"reactor_monitor", "storage_monitor", "ae2_monitor"}
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
    print("Node registered: " .. msg.node_id .. " (" .. msg.node_type .. ")")
  end
  
  if msg.type == "heartbeat" then
    if nodes[msg.node_id] then
      nodes[msg.node_id].version = msg.version
      nodes[msg.node_id].file_hashes = msg.file_hashes or {}
      nodes[msg.node_id].last_seen = os.time()
    end
  end
  
  if msg.type == "node_status" then
    if nodes[msg.node_id] then
      nodes[msg.node_id].last_status = msg
      nodes[msg.node_id].status = msg
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

event.listen("modem_message", handleMessage)

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

  os.sleep(1)
end