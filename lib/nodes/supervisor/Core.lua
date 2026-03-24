local component = require("component")
local computer = require("computer")
local event = require("event")
local serialization = require("serialization")
local fs = require("filesystem")

local modem = component.modem

-- =============================
-- Load node config
-- =============================
local function loadConfig(service_name)
    local cfg_path = "/nodes/config/" .. service_name .. ".cfg"
    if not fs.exists(cfg_path) then
        error("Config file not found: " .. cfg_path)
    end

    local f = io.open(cfg_path, "r")
    local data = f:read("*a")
    f:close()

    local ok, cfg = pcall(load, "return "..data)
    if not ok or type(cfg) ~= "table" then
        error("Failed to load config for " .. service_name)
    end

    return cfg
end

-- =============================
-- Node state
-- =============================
local cfg = loadConfig(os.getenv("SERVICE_NAME") or "default")

local node_id = cfg.node_id or os.getenv("NODE_ID") or ("node_"..math.floor(computer.uptime()))
local node_type = cfg.node_type or "generic"
local tasks = cfg.tasks or {}
local version = cfg.version or "1.0.0"
local orchestrator_channel = cfg.orchestrator_channel or 1234
local heartbeat_interval = cfg.heartbeat_interval or 30

modem.open(orchestrator_channel)

-- =============================
-- Helper functions
-- =============================
local function send(msg)
    modem.broadcast(orchestrator_channel, serialization.serialize(msg))
end

local function writeFile(path, data)
    local dir = path:match("(.*/)")
    if dir and not fs.exists(dir) then fs.makeDirectory(dir) end
    local f = io.open(path, "w")
    f:write(data)
    f:close()
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

-- =============================
-- Registration & heartbeat
-- =============================
local last_heartbeat = 0

local function registerNode()
    send({
        type = "register",
        node_id = node_id,
        node_type = node_type,
        tasks = tasks,
        version = version,
        file_hashes = cfg.file_hashes or {}
    })
end

local function heartbeat()
    local now = computer.uptime()
    if now - last_heartbeat < heartbeat_interval then return end

    send({
        type = "heartbeat",
        node_id = node_id,
        uptime = computer.uptime(),
        version = version,
        file_hashes = cfg.file_hashes or {}
    })

    last_heartbeat = now
end

-- =============================
-- Task loader
-- =============================
local task_modules = {}

for _, task_name in ipairs(tasks) do
    local ok, mod = pcall(require, "/nodes/tasks/"..task_name)
    if ok and type(mod.run) == "function" then
        table.insert(task_modules, mod)
    else
        print("Failed to load task module:", task_name)
    end
end

-- =============================
-- Message handler
-- =============================
local function handleMessage(_, _, from, port, _, raw)
    if port ~= orchestrator_channel then return end
    local ok, msg = pcall(serialization.unserialize, raw)
    if not ok then return end

    -- handle delta / manifest requests
    if msg.type == "delta_response" then
        -- write files to staging area and apply updates
        for path, data in pairs(msg.files) do
            writeFile("/update"..path, data)
        end
        print("Delta update received.")
    end

    if msg.type == "manifest_response" then
        writeFile("/cache/manifest.lua", msg.manifest)
        print("Manifest updated.")
    end
end

event.listen("modem_message", handleMessage)

-- =============================
-- Main supervisor loop
-- =============================
registerNode()

while true do
    -- heartbeat
    pcall(heartbeat)

    -- run tasks
    for _, task in ipairs(task_modules) do
        pcall(task.run, cfg)
    end

    -- run updater if included as task
    if cfg.include_updater and task_modules.updater then
        pcall(task_modules.updater.run)
    end

    os.sleep(1)
end