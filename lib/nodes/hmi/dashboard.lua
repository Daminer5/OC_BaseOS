-- HMI Dashboard
-- Main dashboard application for monitoring all nodes and devices

local component = require("component")
local event = require("event")
local serialization = require("serialization")
local computer = require("computer")

local gpu = component.gpu
local modem = component.modem
local screen = component.screen

local widgets = require("hmi.widgets")
local database = require("database")
local alerts = require("alerts")

-- =============================
-- Configuration
-- =============================

local cfg = {
  orchestrator_channel = 1234,
  hmi_channel = 1235,
  update_interval = 2,
  screen_width = 160,
  screen_height = 50
}

-- =============================
-- Global State
-- =============================

local node_statuses = {}
local device_statuses = {}
local alert_list = {}
local current_view = "overview"  -- overview, nodes, devices, alerts
local current_page = 1

-- =============================
-- Message Handler
-- =============================

local function handleMessage(_, _, from, port, _, raw)
  if port ~= cfg.orchestrator_channel and port ~= cfg.hmi_channel then
    return
  end
  
  local ok, msg = pcall(serialization.unserialize, raw)
  if not ok then return end
  
  -- Handle reactor status
  if msg.type == "reactor_status" then
    for _, reactor_info in ipairs(msg.reactors or {}) do
      device_statuses[reactor_info.address] = {
        type = reactor_info.type,
        status = reactor_info.status,
        timestamp = msg.timestamp
      }
    end
  end
  
  -- Handle storage status
  if msg.type == "storage_status" then
    for _, storage_info in ipairs(msg.storages or {}) do
      device_statuses[storage_info.address] = {
        type = storage_info.type,
        status = storage_info.status,
        timestamp = msg.timestamp
      }
    end
  end
  
  -- Handle AE2 status
  if msg.type == "ae2_status" then
    for _, net_info in ipairs(msg.networks or {}) do
      device_statuses[net_info.address] = {
        type = net_info.type,
        status = net_info.status,
        timestamp = msg.timestamp
      }
    end
  end
  
  -- Handle alerts
  if msg.type == "alerts" then
    alert_list = msg.alerts or {}
  end
end

event.listen("modem_message", handleMessage)

-- =============================
-- View Renderers
-- =============================

local function renderOverview()
  local screen = widgets.Screen.new(cfg.screen_width, cfg.screen_height)
  
  -- Header
  local header = widgets.Header.new("OC_BaseOS Dashboard - Overview", screen.colors)
  screen:addComponent(header)
  
  -- Summary stats
  local stats = database.getStats()
  local alert_stats = alerts.getAlertStats()
  
  local info_widget = {}
  function info_widget:render(gpu)
    gpu.setForeground(0xFFFFFF)
    gpu.set(2, 3, string.format("Nodes Online: %d/%d", stats.online, stats.total))
    gpu.set(2, 4, string.format("Stale Nodes: %d", stats.stale))
    gpu.set(2, 5, string.format("Critical Alerts: %d | Warnings: %d", alert_stats.critical, alert_stats.warning))
  end
  screen:addComponent(info_widget)
  
  -- Alert box
  local alert_box = widgets.AlertNotification.new(1, 7, cfg.screen_width, 8, screen.colors)
  alert_box:setAlerts(alert_list)
  screen:addComponent(alert_box)
  
  -- Status cards for nodes
  local nodes = database.getOnlineNodes()
  local card_y = 16
  local col = 1
  
  for i = 1, math.min(#nodes, 6) do
    local node = nodes[i]
    local health = 1.0
    
    if node.status == "stale" then
      health = 0.5
    end
    
    local card = widgets.StatusCard.new(
      1 + (col - 1) * 55,
      card_y,
      50,
      10,
      node.node_id,
      node.node_type,
      screen.colors
    )
    card:setStatus(node.status, health)
    card:setDetails({
      Type = node.node_type,
      Version = node.version,
      Tasks = #node.tasks
    })
    
    screen:addComponent(card)
    col = col + 1
    if col > 2 then
      col = 1
      card_y = card_y + 11
    end
  end
  
  return screen
end

local function renderNodes()
  local screen = widgets.Screen.new(cfg.screen_width, cfg.screen_height)
  
  local header = widgets.Header.new("OC_BaseOS Dashboard - Nodes", screen.colors)
  screen:addComponent(header)
  
  local nodes = database.getAllNodes()
  local grid = widgets.DataGrid.new(1, 3, cfg.screen_width, cfg.screen_height - 4,
    {"Node ID", "Type", "Status", "Version"}, screen.colors)
  
  for _, node in ipairs(nodes) do
    grid:addRow({
      node.node_id,
      node.node_type,
      node.status,
      node.version
    })
  end
  
  screen:addComponent(grid)
  return screen
end

local function renderDevices()
  local screen = widgets.Screen.new(cfg.screen_width, cfg.screen_height)
  
  local header = widgets.Header.new("OC_BaseOS Dashboard - Devices", screen.colors)
  screen:addComponent(header)
  
  local grid = widgets.DataGrid.new(1, 3, cfg.screen_width, cfg.screen_height - 4,
    {"Address", "Type", "Temp/Cap", "Energy"}, screen.colors)
  
  for addr, device_info in pairs(device_statuses) do
    local status = device_info.status
    local temp_cap = ""
    local energy = ""
    
    if status.temperature and status.temperature > 0 then
      temp_cap = string.format("%dK", status.temperature)
    elseif status.energy_capacity and status.energy_capacity > 0 then
      temp_cap = string.format("%.1f%%", (status.energy_stored / status.energy_capacity) * 100)
    end
    
    if status.energy_capacity > 0 then
      energy = string.format("%d/%d", status.energy_stored, status.energy_capacity)
    end
    
    grid:addRow({
      string.sub(addr, 1, 8),
      status.type,
      temp_cap,
      energy
    })
  end
  
  screen:addComponent(grid)
  return screen
end

local function renderAlerts()
  local screen = widgets.Screen.new(cfg.screen_width, cfg.screen_height)
  
  local header = widgets.Header.new("OC_BaseOS Dashboard - Alerts", screen.colors)
  screen:addComponent(header)
  
  local alert_box = widgets.AlertNotification.new(1, 3, cfg.screen_width, cfg.screen_height - 4, screen.colors)
  alert_box:setAlerts(alert_list)
  screen:addComponent(alert_box)
  
  return screen
end

-- =============================
-- Main Loop
-- =============================

local function run()
  modem.open(cfg.orchestrator_channel)
  modem.open(cfg.hmi_channel)
  
  database.load()
  
  gpu.setResolution(cfg.screen_width, cfg.screen_height)
  
  local last_update = 0
  
  while true do
    local now = computer.uptime()
    
    -- Render screen periodically
    if now - last_update >= cfg.update_interval then
      local screen_obj = nil
      
      if current_view == "overview" then
        screen_obj = renderOverview()
      elseif current_view == "nodes" then
        screen_obj = renderNodes()
      elseif current_view == "devices" then
        screen_obj = renderDevices()
      elseif current_view == "alerts" then
        screen_obj = renderAlerts()
      else
        screen_obj = renderOverview()
      end
      
      if screen_obj then
        screen_obj:render(gpu)
      end
      
      last_update = now
    end
    
    -- Handle touch events
    local ok, signal, x, y = pcall(event.pull, 0.5, "touch")
    if ok and signal == "touch" then
      -- Simple touch navigation
      if y == 1 then
        -- Header clicked - cycle views
        if current_view == "overview" then
          current_view = "nodes"
        elseif current_view == "nodes" then
          current_view = "devices"
        elseif current_view == "devices" then
          current_view = "alerts"
        else
          current_view = "overview"
        end
      end
    end
    
    os.sleep(0.1)
  end
end

return {run = run}
