-- OC_BaseOS installer
-- Usage: install.lua [github_base] [install_root]
-- Example: install.lua https://raw.githubusercontent.com/Daminer5/OC_BaseOS/main /

local component = require("component")
local internet = require("internet")
local filesystem = require("filesystem")
local computer = require("computer")
local event = require("event")
local serialization = require("serialization")

local args = {...}
local configPath = "/lib/updater.cfg"
local updater_config = {
  repo = "https://raw.githubusercontent.com/Daminer5/OC_BaseOS",
  branch = "dev"
}

if filesystem.exists(configPath) then
  local ok, fn = pcall(loadfile, configPath)
  if ok and fn then
    local success, result = pcall(fn)
    if success and type(result) == "table" then
      for k,v in pairs(result) do updater_config[k] = v end
    end
  end
end

local requested = args[1]
local install_root = args[2] or "/"
if install_root:sub(-1) ~= "/" then install_root = install_root .. "/" end

local branch
local github_base
if requested and requested:match("^https?://") then
  github_base = requested
else
  branch = (requested and requested ~= "") and requested or updater_config.branch or "dev"
  io.write("Select branch to use (main/dev) [" .. branch .. "]: ")
  local input = io.read()
  if input and input ~= "" then branch = input end
  updater_config.branch = branch
  github_base = (updater_config.repo or "https://raw.githubusercontent.com/Daminer5/OC_BaseOS") .. "/" .. branch
  -- Persist selection in updater.cfg
  local cfgData = "return {\n  repo = \"" .. updater_config.repo .. "\",\n  branch = \"" .. updater_config.branch .. "\"\n}\n"
  writeFile(configPath, cfgData)
end

if not github_base then
  github_base = "https://raw.githubusercontent.com/Daminer5/OC_BaseOS/dev"
end

local function err(msg)
  io.stderr:write("[install] ERROR: " .. msg .. "\n")
end

local function info(msg)
  io.write("[install] " .. msg .. "\n")
end

local function download(url)
  local ok, handle = pcall(internet.request, url)
  if not ok or not handle then
    return nil, "failed to open URL: " .. tostring(url)
  end

  local data = ""
  for chunk in handle do
    data = data .. chunk
  end

  if data == "" then
    return nil, "empty response from " .. tostring(url)
  end

  return data
end

local function ensureDir(path)
  if not path or path == "" then return true end
  if filesystem.exists(path) then return true end
  local parent = path:match("(.*/)[^/]*$")
  if parent and parent ~= path then
    ensureDir(parent)
  end
  return filesystem.makeDirectory(path)
end

local function writeFile(path, data)
  local dir = path:match("(.*/)[^/]*$") or "/"
  ensureDir(dir)
  local f, errm = io.open(path, "wb")
  if not f then
    return false, errm
  end
  f:write(data)
  f:close()
  return true
end

local function loadManifest(data)
  local ok, m = pcall(load, "return " .. data)
  if not ok or type(m) ~= "table" then
    return nil, "invalid manifest format"
  end
  -- Support both manifest.forms:
  -- 1) { files = { [path] = sha1, ... } }
  -- 2) { common = {...}, nodes = { ... } }
  if m.files and type(m.files) == "table" then
    return m
  end
  if m.common and m.nodes and type(m.nodes) == "table" then
    return m
  end
  return nil, "unknown manifest schema"
end

local function detectHardware()
  local hw = {
    modem = component.isAvailable("modem"),
    gpu = component.isAvailable("gpu"),
    screen = component.isAvailable("screen"),
    keyboard = component.isAvailable("keyboard"),
    filesystem = component.isAvailable("filesystem")
  }

  local device_list = component.list()
  for addr, dtype in component.list() do
    if dtype:match("BigReactors_Reactor") or dtype:match("mek_fission") or dtype:match("mek_fusion") then
      hw.reactor = true
    end
    if dtype:match("MEKismEnergyTank") or dtype:match("EnderIOEnergyBank") or dtype:match("ThermalExpansionEnergyCell") then
      hw.energy_storage = true
    end
    if dtype:match("me_") or dtype:match("appliedenergistics") then
      hw.ae2 = true
    end
    if dtype:match("filesystem") or dtype:match("hard_drive") or dtype:match("floppy") then
      hw.storage = true
    end
    if dtype == "screen" then hw.screen = true end
    if dtype == "gpu" then hw.gpu = true end
    if dtype == "keyboard" then hw.keyboard = true end
  end

  return hw
end

local function findOrchestratorNetwork(timeout)
  local found = { orchestrator = false, database = false, hmi = false }
  if not component.isAvailable("modem") then
    return found
  end

  local modem = component.modem
  local channel = 1234
  modem.open(channel)

  local responses = {}
  local function onMessage(_, _, from, port, _, raw)
    if port ~= channel then return end
    local ok, msg = pcall(serialization.unserialize, raw)
    if not ok or type(msg) ~= "table" then return end

    if msg.type == "node_announce" then
      responses[from] = msg
      if msg.node_type == "orchestrator" then found.orchestrator = true end
      if msg.node_type == "database" then found.database = true end
      if msg.node_type == "hmi" then found.hmi = true end
    end
  end

  local listener = event.listen("modem_message", onMessage)
  modem.broadcast(channel, serialization.serialize({ type = "node_discovery", from = "installer" }))

  local wait_to = computer.uptime() + (timeout or 6)
  while computer.uptime() < wait_to do
    event.pull(0.5)
  end

  event.cancel(listener)
  return found
end

local function inferNodeType(hw, net)
  net = net or {}

  if hw.gpu and hw.screen then
    return "hmi", {"dashboard"}
  end
  if hw.reactor then
    return "reactor", {"reactor_monitor"}
  end
  if hw.ae2 or hw.energy_storage then
    return "storage", {"storage_monitor"}
  end
  if hw.storage and not hw.reactor and not hw.ae2 then
    return "database", {"database"}
  end
  if hw.modem and not hw.screen and not hw.reactor and not hw.ae2 then
    -- no attached devices: join the network as a general node
    if net.orchestrator then
      return "worker", {"reactor_monitor"}
    end
    return "orchestrator", {"orchestrator"}
  end

  return "generic", {}
end

local function gatherManifestFiles(manifest, node_type)
  local files = {}
  if manifest.files then
    for path, _ in pairs(manifest.files) do
      table.insert(files, path)
    end
    return files
  end

  if manifest.common then
    for _, path in ipairs(manifest.common) do
      table.insert(files, path)
    end
  end

  if node_type and manifest.nodes and manifest.nodes[node_type] then
    for _, path in ipairs(manifest.nodes[node_type]) do
      table.insert(files, path)
    end
  end

  return files
end

local function createNodeConfig(node_type, tasks)
  local module_exists, init = pcall(require, "init")
  if not module_exists then return false, "cannot load init module" end

  local node_id = "oc_node_" .. tostring(math.random(1000,9999))
  info("Creating node config for " .. node_type .. " (" .. node_id .. ")")
  local ok = init.createDefaultConfig(node_id, node_type, tasks)
  if not ok then return false, "failed to write node config" end
  return true
end

info("Starting OC_BaseOS installation")
info("GitHub base: " .. github_base)
info("Install root: " .. install_root)

local version_data, version_err = download(github_base .. "/version.txt")
if not version_data then
  err(version_err)
  return
end
version_data = version_data:gsub("\r?\n$", "")
info("remote version " .. version_data)

local manifest_data, manifest_err = download(github_base .. "/manifest.lua")
if not manifest_data then
  err(manifest_err)
  return
end

local manifest, manifest_err2 = loadManifest(manifest_data)
if not manifest then
  err(manifest_err2)
  return
end

local hw = detectHardware()
local net = findOrchestratorNetwork(5)
local node_type, tasks = inferNodeType(hw, net)

info("Hardware detection: modem=" .. tostring(hw.modem) .. ", gpu=" .. tostring(hw.gpu) .. ", screen=" .. tostring(hw.screen) .. ", reactor=" .. tostring(hw.reactor) .. ", ae2=" .. tostring(hw.ae2))
info("Network discovery: orchestrator=" .. tostring(net.orchestrator) .. ", database=" .. tostring(net.database) .. ", hmi=" .. tostring(net.hmi))
info("Inferred node type: " .. node_type)

if node_type ~= "generic" then
  local ok, cfgerr = createNodeConfig(node_type, tasks)
  if not ok then
    err(cfgerr)
  end
end

local filelist = gatherManifestFiles(manifest, node_type)
if #filelist == 0 then
  err("manifest contains no files for node type " .. tostring(node_type))
  return
end

for _, sourcePath in ipairs(filelist) do
  if sourcePath:sub(1,1) ~= "/" then
    sourcePath = "/" .. sourcePath
  end

  local dstPath = install_root .. sourcePath:gsub("^/", "")
  local remoteUrl = github_base .. sourcePath

  info("Downloading " .. sourcePath)
  local content, dlerr = download(remoteUrl)
  if not content then
    err("Failed to download " .. remoteUrl .. ": " .. dlerr)
    return
  end

  local ok, werr = writeFile(dstPath, content)
  if not ok then
    err("Failed to write " .. dstPath .. ": " .. tostring(werr))
    return
  end

  info("Wrote " .. dstPath)
end

local ok, werr = writeFile(install_root .. "cache/version.txt", version_data)
if not ok then err("Failed writing version cache: " .. tostring(werr)); return end
ok, werr = writeFile(install_root .. "cache/manifest.lua", manifest_data)
if not ok then err("Failed writing manifest cache: " .. tostring(werr)); return end

info("Installation complete. Node type: " .. node_type)
info("Restart nodes or run services as needed.")
