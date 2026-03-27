-- Database/Registry System
-- Persists node registry with state tracking, staleness detection, and query interface

local filesystem = require("filesystem")
local serialization = require("serialization")
local computer = require("computer")

local M = {}

-- =============================
-- Configuration
-- =============================

M.REGISTRY_FILE = "/var/node_registry.lua"
M.REGISTRY_BACKUP = "/var/node_registry.backup.lua"
M.STALENESS_THRESHOLD = 60  -- seconds without heartbeat = stale
M.AUTO_SAVE_INTERVAL = 30   -- save to disk every 30 seconds

-- In-memory registry
M.nodes = {}

-- Tracking
M.last_save = computer.uptime()

-- =============================
-- Utility Functions
-- =============================

local function ensureDir(path)
  local dir = path:match("(.*/)[^/]*$") or "/"
  if not filesystem.exists(dir) then
    filesystem.makeDirectory(dir)
  end
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
  ensureDir(path)
  local f = io.open(path, "w")
  if not f then return false end
  f:write(data)
  f:close()
  return true
end

-- =============================
-- Loading & Saving
-- =============================

function M.load()
  -- Load registry from disk
  local data = readFile(M.REGISTRY_FILE)
  if not data then
    M.nodes = {}
    return
  end
  
  local ok, registry = pcall(load, "return " .. data)
  if ok and type(registry) == "table" then
    M.nodes = registry
  else
    M.nodes = {}
  end
end

function M.save()
  -- Serialize and save to disk
  ensureDir(M.REGISTRY_FILE)
  
  -- Backup old registry
  if filesystem.exists(M.REGISTRY_FILE) then
    local data = readFile(M.REGISTRY_FILE)
    writeFile(M.REGISTRY_BACKUP, data)
  end
  
  -- Save current registry
  local serialized = serialization.serialize(M.nodes)
  return writeFile(M.REGISTRY_FILE, serialized)
end

function M.autoSave()
  -- Save periodically to prevent data loss
  local now = computer.uptime()
  if now - M.last_save >= M.AUTO_SAVE_INTERVAL then
    M.save()
    M.last_save = now
  end
end

-- =============================
-- Node Registration
-- =============================

function M.registerNode(node_id, node_type, tasks, version, file_hashes)
  if not node_id then return false end
  
  M.nodes[node_id] = {
    node_id = node_id,
    node_type = node_type or "generic",
    tasks = tasks or {},
    version = version or "0.0.0",
    file_hashes = file_hashes or {},
    registered_at = os.time(),
    last_heartbeat = os.time(),
    uptime = 0,
    status = "online"
  }
  
  return true
end

function M.updateHeartbeat(node_id, uptime, version, file_hashes)
  if not M.nodes[node_id] then
    return false
  end
  
  local node = M.nodes[node_id]
  node.last_heartbeat = os.time()
  node.uptime = uptime or 0
  node.version = version or node.version
  node.file_hashes = file_hashes or node.file_hashes
  node.status = "online"
  
  return true
end

-- =============================
-- Staleness Detection
-- =============================

function M.updateStaleness()
  -- Mark nodes as stale if no heartbeat
  local now = os.time()
  for node_id, node in pairs(M.nodes) do
    local last_seen = node.last_heartbeat or node.registered_at or 0
    if now - last_seen > M.STALENESS_THRESHOLD then
      node.status = "stale"
    else
      node.status = "online"
    end
  end
end

function M.isStale(node_id)
  if not M.nodes[node_id] then return true end
  return M.nodes[node_id].status == "stale"
end

function M.removeStaleNodes(max_age_seconds)
  -- Remove nodes that haven't been seen in a long time
  max_age_seconds = max_age_seconds or 3600  -- 1 hour default
  local now = os.time()
  local removed = {}
  
  for node_id, node in pairs(M.nodes) do
    local last_seen = node.last_heartbeat or node.registered_at or 0
    if now - last_seen > max_age_seconds then
      M.nodes[node_id] = nil
      table.insert(removed, node_id)
    end
  end
  
  return removed
end

-- =============================
-- Querying
-- =============================

function M.getNode(node_id)
  return M.nodes[node_id]
end

function M.getAllNodes()
  local list = {}
  for node_id, node in pairs(M.nodes) do
    table.insert(list, node)
  end
  return list
end

function M.getNodesByType(node_type)
  local list = {}
  for node_id, node in pairs(M.nodes) do
    if node.node_type == node_type then
      table.insert(list, node)
    end
  end
  return list
end

function M.getNodesByTask(task_name)
  local list = {}
  for node_id, node in pairs(M.nodes) do
    for _, task in ipairs(node.tasks or {}) do
      if task == task_name then
        table.insert(list, node)
        break
      end
    end
  end
  return list
end

function M.getOnlineNodes()
  local list = {}
  for node_id, node in pairs(M.nodes) do
    if node.status == "online" then
      table.insert(list, node)
    end
  end
  return list
end

function M.getNodeCount()
  local count = 0
  for _ in pairs(M.nodes) do count = count + 1 end
  return count
end

function M.getStats()
  local total = 0
  local online = 0
  local stale = 0
  
  for _, node in pairs(M.nodes) do
    total = total + 1
    if node.status == "online" then
      online = online + 1
    elseif node.status == "stale" then
      stale = stale + 1
    end
  end
  
  return {
    total = total,
    online = online,
    stale = stale,
    offline = total - online - stale
  }
end

-- =============================
-- Update Tracking
-- =============================

function M.getNodeOutOfDate(latest_version)
  -- Return nodes not on latest version
  local list = {}
  for node_id, node in pairs(M.nodes) do
    if node.version ~= latest_version then
      table.insert(list, {node_id = node_id, current = node.version, latest = latest_version})
    end
  end
  return list
end

function M.getNodeWithIncorrectFiles(manifest)
  -- Return nodes with mismatched file hashes
  if not manifest or not manifest.files then return {} end
  
  local list = {}
  for node_id, node in pairs(M.nodes) do
    local incorrect_count = 0
    for filepath, expected_hash in pairs(manifest.files) do
      local local_hash = node.file_hashes[filepath]
      if local_hash ~= expected_hash then
        incorrect_count = incorrect_count + 1
      end
    end
    
    if incorrect_count > 0 then
      table.insert(list, {
        node_id = node_id,
        incorrect_files = incorrect_count,
        total_files = 0
      })
      list[#list].total_files = 0
      for _ in pairs(manifest.files) do list[#list].total_files = list[#list].total_files + 1 end
    end
  end
  return list
end

-- =============================
-- Cleanup & Maintenance
-- =============================

function M.clear()
  M.nodes = {}
  return M.save()
end

function M.reset()
  M.nodes = {}
end

return M
