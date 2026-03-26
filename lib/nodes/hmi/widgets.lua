-- HMI Widgets Library
-- Provides reusable UI components for touchscreen display

local M = {}

-- =============================
-- Screen Management
-- =============================

M.Screen = {}
M.Screen.__index = M.Screen

function M.Screen.new(width, height)
  local screen = {
    width = width or 160,
    height = height or 50,
    components = {},
    colors = {
      bg = 0x000000,
      fg = 0xFFFFFF,
      header = 0x0066FF,
      footer = 0x666666,
      alert_critical = 0xFF0000,
      alert_warning = 0xFFFF00,
      alert_info = 0x00FF00,
      border = 0x333333,
      disabled = 0x999999
    }
  }
  
  return setmetatable(screen, M.Screen)
end

function M.Screen:addComponent(component)
  table.insert(self.components, component)
end

function M.Screen:render(gpu)
  -- Clear screen
  gpu.setBackground(self.colors.bg)
  gpu.setForeground(self.colors.fg)
  gpu.fill(1, 1, self.width, self.height, " ")
  
  -- Render all components
  for _, component in ipairs(self.components) do
    if component.render then
      component:render(gpu)
    end
  end
end

-- =============================
-- Widget: Header
-- =============================

M.Header = {}
M.Header.__index = M.Header

function M.Header.new(title, colors)
  return setmetatable({
    title = title or "OC_BaseOS Dashboard",
    x = 1,
    y = 1,
    width = 160,
    height = 1,
    colors = colors or {}
  }, M.Header)
end

function M.Header:render(gpu)
  gpu.setBackground(self.colors.header or 0x0066FF)
  gpu.setForeground(0xFFFFFF)
  gpu.fill(self.x, self.y, self.width, self.height, " ")
  gpu.set(self.x + 2, self.y, self.title)
end

-- =============================
-- Widget: Node Status Card
-- =============================

M.StatusCard = {}
M.StatusCard.__index = M.StatusCard

function M.StatusCard.new(x, y, width, height, node_id, node_type, colors)
  return setmetatable({
    x = x,
    y = y,
    width = width or 40,
    height = height or 10,
    node_id = node_id,
    node_type = node_type,
    status = "offline",
    health = 0.5,
    colors = colors or {},
    details = {}
  }, M.StatusCard)
end

function M.StatusCard:setStatus(status, health)
  self.status = status
  self.health = math.max(0, math.min(1, health or 0.5))
end

function M.StatusCard:setDetails(details)
  self.details = details or {}
end

function M.StatusCard:render(gpu)
  -- Border
  local border_color = 0x333333
  gpu.setForeground(border_color)
  
  -- Top border
  gpu.set(self.x, self.y, "┌" .. string.rep("─", self.width - 2) .. "┐")
  
  -- Side borders and content
  for i = 1, self.height - 2 do
    gpu.set(self.x, self.y + i, "│")
    gpu.set(self.x + self.width - 1, self.y + i, "│")
  end
  
  -- Bottom border
  gpu.set(self.x, self.y + self.height - 1, "└" .. string.rep("─", self.width - 2) .. "┘")
  
  -- Content area
  gpu.setForeground(0xFFFFFF)
  
  -- Node ID
  local title = string.sub(self.node_id, 1, self.width - 4)
  gpu.set(self.x + 2, self.y + 1, title)
  
  -- Status indicator
  local status_color = 0xFF0000  -- red (offline)
  if self.status == "online" then
    status_color = 0x00FF00  -- green
  elseif self.status == "stale" then
    status_color = 0xFFFF00  -- yellow
  end
  gpu.setForeground(status_color)
  gpu.set(self.x + self.width - 3, self.y + 1, "●")
  
  -- Health bar
  gpu.setForeground(0xFFFFFF)
  gpu.set(self.x + 2, self.y + 2, "Health:")
  local bar_width = self.width - 10
  local filled = math.floor(bar_width * self.health)
  gpu.setForeground(0x00FF00)
  gpu.set(self.x + 10, self.y + 2, string.rep("█", filled) .. string.rep("░", bar_width - filled))
  
  -- Details
  gpu.setForeground(0xCCCCCC)
  local line = 3
  for key, value in pairs(self.details) do
    if line < self.height - 1 then
      local detail_str = string.format("%s: %s", key, tostring(value))
      detail_str = string.sub(detail_str, 1, self.width - 4)
      gpu.set(self.x + 2, self.y + line, detail_str)
      line = line + 1
    end
  end
end

-- =============================
-- Widget: Alert Notification
-- =============================

M.AlertNotification = {}
M.AlertNotification.__index = M.AlertNotification

function M.AlertNotification.new(x, y, width, height, colors)
  return setmetatable({
    x = x,
    y = y,
    width = width or 160,
    height = height or 5,
    alerts = {},
    colors = colors or {}
  }, M.AlertNotification)
end

function M.AlertNotification:setAlerts(alerts)
  self.alerts = alerts or {}
end

function M.AlertNotification:render(gpu)
  local bg_color = 0x220000  -- dark red background
  gpu.setBackground(bg_color)
  gpu.fill(self.x, self.y, self.width, self.height, " ")
  
  if #self.alerts == 0 then
    gpu.setForeground(0x00FF00)
    gpu.set(self.x + 2, self.y + 1, "No active alerts")
    return
  end
  
  -- Show first few alerts
  for i = 1, math.min(#self.alerts, self.height - 1) do
    local alert = self.alerts[i]
    local color = 0xFF0000  -- critical red
    
    if alert.severity_name == "WARNING" then
      color = 0xFFFF00  -- yellow
    elseif alert.severity_name == "INFO" then
      color = 0x00FF00  -- green
    end
    
    gpu.setForeground(color)
    local alert_str = string.format("[%s] %s: %s", alert.severity_name, alert.device_id, alert.message)
    alert_str = string.sub(alert_str, 1, self.width - 4)
    gpu.set(self.x + 2, self.y + i, alert_str)
  end
  
  gpu.setBackground(0x000000)
end

-- =============================
-- Widget: Data Grid
-- =============================

M.DataGrid = {}
M.DataGrid.__index = M.DataGrid

function M.DataGrid.new(x, y, width, height, columns, colors)
  return setmetatable({
    x = x,
    y = y,
    width = width or 160,
    height = height or 20,
    columns = columns or {"Name", "Status", "Value"},
    rows = {},
    colors = colors or {},
    scroll_offset = 0
  }, M.DataGrid)
end

function M.DataGrid:addRow(row_data)
  table.insert(self.rows, row_data)
end

function M.DataGrid:setRows(rows)
  self.rows = rows or {}
end

function M.DataGrid:render(gpu)
  -- Header
  gpu.setBackground(0x0066FF)
  gpu.setForeground(0xFFFFFF)
  
  local col_width = math.floor((self.width - 2) / #self.columns)
  local header_str = ""
  for _, col in ipairs(self.columns) do
    header_str = header_str .. string.sub(col, 1, col_width):ljust(col_width)
  end
  gpu.set(self.x + 1, self.y, header_str)
  
  -- Rows
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
  
  local max_rows = self.height - 1
  for i = 1, max_rows do
    local row_idx = self.scroll_offset + i
    if row_idx <= #self.rows then
      local row = self.rows[row_idx]
      local row_str = ""
      for _, col_idx in ipairs({1, 2, 3}) do
        local val = row[col_idx] or ""
        row_str = row_str .. string.sub(tostring(val), 1, col_width):ljust(col_width)
      end
      gpu.set(self.x + 1, self.y + i, row_str)
    else
      break
    end
  end
end

return M
