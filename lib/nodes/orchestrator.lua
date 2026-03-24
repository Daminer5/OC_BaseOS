local component = require("component")
local event = require("event")
local internet = require("internet")
local serialization = require("serialization")
local computer = require("computer")

local modem = component.modem
local cfg = require("config")
modem.open(cfg.channel)

-- Dynamic node registry
local nodes = {}

-- helpers
local function download(url)
  local handle = internet.request(url)
  local data = ""
  for chunk in handle do data = data .. chunk end
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

-- handle node messages
local function handleMessage(_, _, from, port, _, raw)
  if port ~= cfg.channel then return end
  local ok, msg = pcall(serialization.unserialize, raw)
  if not ok then return end

  if msg.type == "register" or msg.type == "heartbeat" then
    nodes[msg.node_id] = nodes[msg.node_id] or {}
    local node = nodes[msg.node_id]

    node.node_type = msg.node_type
    node.tasks = msg.tasks
    node.version = msg.version
    node.file_hashes = msg.file_hashes
    node.last_seen = os.time()
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
end

event.listen("modem_message", handleMessage)

-- main loop
local lastSync = 0
while true do
  local now = computer.uptime()
  if now - lastSync > cfg.sync_interval then
    pcall(sync)
    lastSync = now
  end

  -- broadcast current version to all nodes
  for node_id, node in pairs(nodes) do
    modem.broadcast(cfg.channel, serialization.serialize({
      type = "version_announce",
      version = CURRENT_VERSION,
      node_id = node_id
    }))
  end

  os.sleep(1)
end