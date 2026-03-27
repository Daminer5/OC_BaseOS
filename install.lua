local component = require("component")
local internet = require("internet")
local filesystem = require("filesystem")
local computer = require("computer")
local event = require("event")
local serialization = require("serialization")

local function log(msg)
  io.write("[install] " .. msg .. "\n")
end

local function download(url)
  log("Downloading: " .. url)
  local ok, handle = pcall(internet.request, url)
  if not ok or not handle then
    return nil, "Failed to open URL"
  end
  local data = ""
  for chunk in handle do
    data = data .. chunk
  end
  if data == "" then
    return nil, "Empty response"
  end
  return data
end

local function ensureDir(path)
  if not path or path == "" then return true end
  if filesystem.exists(path) then return true end
  local parent = path:match("(.*/)")
  if parent then ensureDir(parent) end
  return filesystem.makeDirectory(path)
end

local function writeFile(path, data)
  local dir = path:match("(.*)/")
  if dir then ensureDir(dir) end
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(data)
  f:close()
  return true
end

local function loadManifest(data)
  if not data or type(data) ~= "string" then
    return nil
  end

  local chunk = data
  if not chunk:match("^%s*return%s+") then
    chunk = "return " .. chunk
  end

  local fn, err = load(chunk, "manifest")
  if not fn then
    return nil
  end

  local ok, m = pcall(fn)
  if not ok or type(m) ~= "table" then
    return nil
  end
  return m
end

local args = {...}
local configPath = "/lib/updater.cfg"
local defaultBranch = "dev"
local defaultRepo = "https://raw.githubusercontent.com/Daminer5/OC_BaseOS/refs/heads"
local branch = defaultBranch
local repo = defaultRepo

if filesystem.exists(configPath) then
  local ok, fn = pcall(loadfile, configPath)
  if ok and fn then
    local ok2, cfg = pcall(fn)
    if ok2 and type(cfg) == "table" then
      branch = cfg.branch or branch
      repo = cfg.repo or repo
    end
  end
end

local arg1 = args[1] or ""
local install_root = args[2] or "/"

if arg1:find("://") then
  repo = arg1
else
  if arg1 ~= "" then branch = arg1 end
  io.write("Branch [" .. branch .. "]: ")
  local input = io.read()
  if input and input ~= "" then branch = input end
end

if install_root:sub(-1) ~= "/" then
  install_root = install_root .. "/"
end

-- Normalize repo and branch to clean URL bases
repo = repo:gsub("/+$", "")
branch = branch:gsub("^/+", "")

local github_base = repo .. "/" .. branch
log("Using: " .. github_base)

local function detectHardware()
  local hw = {}
  hw.modem = component.isAvailable("modem")
  hw.gpu = component.isAvailable("gpu")
  hw.screen = component.isAvailable("screen")
  hw.keyboard = component.isAvailable("keyboard")
  for a, t in component.list() do
    if t:find("Reactor") or t:find("reactor") then hw.reactor = true end
    if t:find("me_") then hw.ae2 = true end
    if t:find("EnderIO") or t:find("Thermal") or t:find("Mekanism") then hw.storage = true end
  end
  return hw
end

local function inferNodeType(hw)
  if hw.gpu and hw.screen then return "hmi" end
  if hw.reactor then return "reactor" end
  if hw.ae2 then return "storage" end
  if hw.storage then return "database" end
  if hw.modem then return "worker" end
  return "generic"
end

log("Starting installation from: " .. github_base)

local version_url = github_base .. "/version.txt"
local manifest_url = github_base .. "/manifest.lua"

local version_data = download(version_url)
if not version_data then
  log("Failed to download version.txt from: " .. version_url)
  return
end

log("Downloaded version.txt: " .. version_data:gsub("\n", ""))

local manifest_data = download(manifest_url)
if not manifest_data then
  log("Failed to download manifest")
  return
end

local manifest = loadManifest(manifest_data)
if not manifest then
  log("Failed to parse manifest")
  return
end

log("Version: " .. version_data:gsub("\n", ""))

local hw = detectHardware()
local node_type = inferNodeType(hw)
log("Node type: " .. node_type)

local filelist = {}
if manifest.files then
  for path, _ in pairs(manifest.files) do
    table.insert(filelist, path)
  end
elseif manifest.common then
  for _, path in ipairs(manifest.common) do
    table.insert(filelist, path)
  end
  if manifest.nodes and manifest.nodes[node_type] then
    for _, path in ipairs(manifest.nodes[node_type]) do
      table.insert(filelist, path)
    end
  end
end

log("Downloading " .. #filelist .. " files")

for _, filepath in ipairs(filelist) do
  local url = github_base .. filepath
  local content = download(url)
  if not content then
    log("FAILED: " .. url)
    return
  end

  local dstpath = install_root .. filepath:gsub("^/", "")
  if not writeFile(dstpath, content) then
    log("FAILED to write: " .. dstpath)
    return
  end
  log("  OK: " .. dstpath)
end

ensureDir(install_root .. "cache")
writeFile(install_root .. "cache/version.txt", version_data)
writeFile(install_root .. "cache/manifest.lua", manifest_data)

log("Installation complete!")

